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

resource "aws_launch_template" "gitlab_runner" {
  count    = var.enabled ? 1 : 0
  image_id = local.asg_runners_ami
  # Only set instance_type when not using attribute-based instance selection
  instance_type          = var.use_attribute_based_instance_selection ? null : var.asg_runners_ec2_type
  vpc_security_group_ids = var.asg_security_groups
  # Note: instance_market_options removed - spot/on-demand mix is controlled by mixed_instances_policy

  lifecycle {
    precondition {
      condition     = var.use_attribute_based_instance_selection || var.asg_runners_ec2_type != null
      error_message = "asg_runners_ec2_type must be set when use_attribute_based_instance_selection is false. Ensure the instance type matches your AMI architecture (x86_64 or ARM64)."
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.asg_iam_instance_profile != null ? [var.asg_iam_instance_profile] : []
    content {
      arn  = startswith(iam_instance_profile.value, "arn:") ? iam_instance_profile.value : null
      name = startswith(iam_instance_profile.value, "arn:") ? null : iam_instance_profile.value
    }
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

            allowed_instance_types = var.allowed_instance_types
            burstable_performance  = var.burstable_performance
            cpu_manufacturers      = var.cpu_manufacturers
            instance_generations   = var.instance_generations
            local_storage_types    = var.local_storage_types
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
  vpc_security_group_ids = var.manager_security_groups
  # Manager instance is always on-demand (no instance_market_options)
  # vpc_security_group_ids = [aws_security_group.allow_ssh_docker.id]
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
