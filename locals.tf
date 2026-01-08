locals {
  # Backward-compatible naming logic
  name_suffix = var.name_prefix != "" ? "-${var.name_prefix}" : ""

  # Resource names with backward compatibility
  iam_policy_name  = "docker-autoscaler${local.name_suffix}"
  iam_role_name    = "gitlab-runner-manager-role${local.name_suffix}"
  iam_profile_name = "gitlab-runner-profile${local.name_suffix}"

  # Determine if we should create security group:
  # - If explicitly set (true/false), use that value
  # - If null (default), create when either ASG or manager has no custom SGs
  #   This ensures manager and runners can always communicate through the shared SG
  create_security_group = var.create_security_group != null ? var.create_security_group : (
    length(var.asg_security_groups) == 0 || length(var.manager_security_groups) == 0
  )

  subnet_vpc_ids          = [for subnet in data.aws_subnet.asg : subnet.vpc_id]
  subnet_vpc_ids_distinct = distinct(local.subnet_vpc_ids)
  vpc_id_from_subnets = length(local.subnet_vpc_ids_distinct) == 1 ? local.subnet_vpc_ids_distinct[0] : null
  vpc_id_effective = (var.vpc_id != null && var.vpc_id != "") ? var.vpc_id : local.vpc_id_from_subnets

  # Combined security groups: module-created SG + user-provided SGs
  module_security_group = var.enabled && local.create_security_group ? [aws_security_group.gitlab_runner[0].id] : []
  asg_security_groups   = concat(local.module_security_group, var.asg_security_groups)
  manager_security_groups = concat(local.module_security_group, var.manager_security_groups)

  # IAM instance profile for ASG runners: use module-created or user-provided
  asg_iam_instance_profile_name = var.asg_iam_instance_profile != null ? var.asg_iam_instance_profile : (
    var.enabled ? aws_iam_instance_profile.gitlab_runner_asg_profile[0].name : null
  )

  base_policy = var.enabled ? templatefile("${path.module}/policies/instance-docker-autoscaler-policy.json.tftpl",
    {
      autoscaling_group_arn  = aws_autoscaling_group.gitlab_runners[0].arn
      autoscaling_group_name = aws_autoscaling_group.gitlab_runners[0].name
      aws_region             = data.aws_region.current.id
      aws_account_id         = data.aws_caller_identity.current.account_id
      enable_s3_cache        = var.enable_s3_cache
      s3_cache_bucket_arn    = var.enable_s3_cache ? aws_s3_bucket.s3_cache[0].arn : null
  }) : null

  manager_policy = var.enabled && local.base_policy != null ? (
    var.extra_policy_entries != null ? merge(
      jsondecode(local.base_policy),
      var.extra_policy_entries
    ) : jsondecode(local.base_policy)
  ) : null

  asg_runners_ami  = var.asg_runners_ami != null ? var.asg_runners_ami : data.aws_ami.latest_amazon_ecs_linux_2023.id
  concurrent_limit = var.asg_max_size * var.capacity_per_instance

}
