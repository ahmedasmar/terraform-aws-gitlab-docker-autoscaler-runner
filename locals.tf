locals {
  # Backward-compatible naming logic
  name_suffix = var.name_prefix != "" ? "-${var.name_prefix}" : ""

  # Resource names with backward compatibility
  iam_policy_name  = "docker-autoscaler${local.name_suffix}"
  iam_role_name    = "gitlab-runner-manager-role${local.name_suffix}"
  iam_profile_name = "gitlab-runner-profile${local.name_suffix}"

  base_policy = templatefile("${path.module}/policies/instance-docker-autoscaler-policy.json.tftpl",
    {
      autoscaling_group_arn  = aws_autoscaling_group.gitlab-runners[0].arn
      autoscaling_group_name = aws_autoscaling_group.gitlab-runners[0].name
      aws_region             = data.aws_region.current.name
      aws_account_id         = data.aws_caller_identity.current.account_id
      enable_s3_cache        = var.enable_s3_cache
      s3_cache_bucket_arn    = var.enable_s3_cache ? aws_s3_bucket.s3_cache[0].arn : null
  })
  manager_policy = var.extra_policy_entries != null ? merge(
    jsondecode(local.base_policy),
    var.extra_policy_entries
  ) : jsondecode(local.base_policy)

  asg_runners_ami  = var.asg_runners_ami != null ? var.asg_runners_ami : data.aws_ami.latest_amazon_ecs_linux_2023.id
  concurrent_limit = var.asg_max_size * var.capacity_per_instance

}
