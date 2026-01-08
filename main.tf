# Security group for manager and runner communication
resource "aws_security_group" "gitlab_runner" {
  count       = var.enabled && local.create_security_group ? 1 : 0
  name        = "gitlab-runner-sg${local.name_suffix}"
  description = "Security group for GitLab Runner manager and ASG runners communication"
  vpc_id      = local.vpc_id_effective

  tags = merge(var.tags, {
    Name = "gitlab-runner-sg${local.name_suffix}"
  })

  lifecycle {
    precondition {
      condition     = local.vpc_id_effective != null && local.vpc_id_effective != ""
      error_message = "vpc_id is required when create_security_group is true unless it can be derived from asg_subnets in a single VPC."
    }
  }
}

# Allow all traffic within the security group (manager <-> runners)
resource "aws_security_group_rule" "gitlab_runner_self_ingress" {
  count             = var.enabled && local.create_security_group ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.gitlab_runner[0].id
  description       = "Allow all traffic between manager and runners"
}

# Allow all outbound traffic
resource "aws_security_group_rule" "gitlab_runner_egress" {
  count             = var.enabled && local.create_security_group ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.gitlab_runner[0].id
  description       = "Allow all outbound traffic"
}

resource "aws_iam_policy" "gitlab_runner_manager_policy" {
  count  = var.enabled && var.create_manager ? 1 : 0
  name   = local.iam_policy_name
  policy = jsonencode(local.manager_policy)
}

resource "aws_iam_role" "gitlab_runner_manager_role" {
  count = var.enabled && var.create_manager ? 1 : 0
  name  = local.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "gitlab_runner_manager_profile" {
  count = var.enabled && var.create_manager ? 1 : 0
  name  = local.iam_profile_name
  role  = aws_iam_role.gitlab_runner_manager_role[0].name
}

resource "aws_iam_role_policy_attachments_exclusive" "gitlab_runner_manager" {
  count     = var.enabled && var.create_manager ? 1 : 0
  role_name = aws_iam_role.gitlab_runner_manager_role[0].name
  policy_arns = [
    aws_iam_policy.gitlab_runner_manager_policy[0].arn,
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

# IAM resources for ASG runners (created by default with AdministratorAccess)
# Only created when asg_iam_instance_profile is not provided
resource "aws_iam_role" "gitlab_runner_asg_role" {
  count = var.enabled && var.asg_iam_instance_profile == null ? 1 : 0
  name  = "gitlab-runner-asg-role${local.name_suffix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(var.tags, {
    Name = "gitlab-runner-asg-role${local.name_suffix}"
  })
}

resource "aws_iam_instance_profile" "gitlab_runner_asg_profile" {
  count = var.enabled && var.asg_iam_instance_profile == null ? 1 : 0
  name  = "gitlab-runner-asg-profile${local.name_suffix}"
  role  = aws_iam_role.gitlab_runner_asg_role[0].name

  tags = merge(var.tags, {
    Name = "gitlab-runner-asg-profile${local.name_suffix}"
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_runner_asg_admin" {
  count      = var.enabled && var.asg_iam_instance_profile == null ? 1 : 0
  role       = aws_iam_role.gitlab_runner_asg_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_launch_template" "gitlab_runner" {
  count    = var.enabled ? 1 : 0
  image_id = local.asg_runners_ami
  # Only set instance_type when not using attribute-based instance selection
  instance_type          = var.use_attribute_based_instance_selection ? null : var.asg_runners_ec2_type
  vpc_security_group_ids = local.asg_security_groups
  # Note: instance_market_options removed - spot/on-demand mix is controlled by mixed_instances_policy

  lifecycle {
    precondition {
      condition     = var.use_attribute_based_instance_selection || var.asg_runners_ec2_type != null
      error_message = "asg_runners_ec2_type must be set when use_attribute_based_instance_selection is false. Ensure the instance type matches your AMI architecture (x86_64 or ARM64)."
    }
  }

  iam_instance_profile {
    name = local.asg_iam_instance_profile_name
  }

  dynamic "tag_specifications" {
    for_each = length(var.tags) > 0 ? [1] : []
    content {
      resource_type = "instance"
      tags          = var.tags
    }

  }
}
resource "aws_autoscaling_group" "gitlab_runners" {
  count                 = var.enabled ? 1 : 0
  max_size              = var.asg_max_size
  min_size              = 0
  desired_capacity      = 0
  vpc_zone_identifier   = var.asg_subnets
  suspended_processes   = ["AZRebalance"]
  protect_from_scale_in = true
  # capacity_rebalance disabled to prevent ASG from externally terminating instances
  # which causes job failures with "instance unexpectedly removed" errors
  capacity_rebalance = false

  # Runner instances use mixed_instances_policy for spot/on-demand control
  # Default: 100% spot (on_demand_percentage_above_base_capacity = 0)
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base_capacity
      spot_allocation_strategy                 = var.spot_allocation_strategy
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.gitlab_runner[0].id
        version            = "$Latest"
      }

      # Override for attribute-based instance selection
      dynamic "override" {
        for_each = var.use_attribute_based_instance_selection ? [1] : []
        content {
          instance_requirements {
            vcpu_count {
              min = var.vcpu_count_min
              max = var.vcpu_count_max
            }

            memory_mib {
              min = var.memory_mib_min
              max = var.memory_mib_max
            }

            # AWS allows only one of AllowedInstanceTypes or ExcludedInstanceTypes.
            allowed_instance_types  = length(var.excluded_instance_types) == 0 ? var.allowed_instance_types : null
            excluded_instance_types = length(var.excluded_instance_types) > 0 ? var.excluded_instance_types : null
            burstable_performance   = var.burstable_performance
            cpu_manufacturers       = var.cpu_manufacturers
            instance_generations    = var.instance_generations
            local_storage           = var.local_storage
            local_storage_types     = var.local_storage == "included" ? var.local_storage_types : []

            dynamic "network_bandwidth_gbps" {
              for_each = var.network_bandwidth_gbps_max != null ? [1] : []
              content {
                max = var.network_bandwidth_gbps_max
              }
            }

            dynamic "accelerator_count" {
              for_each = var.accelerator_count_max != null ? [1] : []
              content {
                max = var.accelerator_count_max
              }
            }
          }
        }
      }

      # Override for specific instance type mode
      dynamic "override" {
        for_each = var.use_attribute_based_instance_selection ? [] : [1]
        content {
          instance_type = var.asg_runners_ec2_type
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }
}

resource "aws_instance" "gitlab_runner" {
  count                  = var.enabled && var.create_manager && var.auth_token != null ? 1 : 0
  ami                    = data.aws_ami.latest_amazon_linux_2023.image_id
  instance_type          = var.manager_ec2_type
  iam_instance_profile   = aws_iam_instance_profile.gitlab_runner_manager_profile[0].name
  subnet_id              = var.asg_subnets[0]
  vpc_security_group_ids = local.manager_security_groups
  # Manager instance is always on-demand (no instance_market_options)
  tags = merge(var.tags, {
    Name = "Gitlab runner autoscaling manager${local.name_suffix}"
  })
  user_data_replace_on_change = true
  # User data script to install Docker and GitLab Runner
  user_data = templatefile("${path.module}/user-data/manager-user-data.sh.tftpl",
    {
      enable_s3_cache        = var.enable_s3_cache
      s3_bucket_name         = var.enable_s3_cache ? aws_s3_bucket.s3_cache[0].id : null
      aws_region             = data.aws_region.current.id
      autoscaling_group_name = aws_autoscaling_group.gitlab_runners[0].name
      auth_token             = var.auth_token
      concurrent_limit       = local.concurrent_limit
      max_instances          = var.asg_max_size
      capacity_per_instance  = var.capacity_per_instance

  })
  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}

resource "aws_s3_bucket" "s3_cache" {
  count  = var.enabled && var.enable_s3_cache ? 1 : 0
  bucket = "gitlab-shared-cache-${random_id.this.hex}"
  tags = merge(var.tags, {
    Service = "Gitlab runner s3 shared cache"
    Name    = "gitlab-shared-cache-${random_id.this.hex}"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_cache" {
  count  = var.enabled && var.enable_s3_cache && var.s3_cache_expiration_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.s3_cache[0].id

  rule {
    id     = "cache_expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = var.s3_cache_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.s3_cache_expiration_days
    }
  }
}

resource "random_id" "this" {
  byte_length = 8
}
