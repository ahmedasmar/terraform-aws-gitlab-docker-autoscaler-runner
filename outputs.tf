output "autoscaling_group_name" {
  description = "Name of the GitLab Runner autoscaling group"
  value       = var.enabled ? aws_autoscaling_group.gitlab-runners[0].name : null
}

output "autoscaling_group_arn" {
  description = "ARN of the GitLab Runner autoscaling group"
  value       = var.enabled ? aws_autoscaling_group.gitlab-runners[0].arn : null
}

output "launch_template_id" {
  description = "ID of the launch template used by the autoscaling group"
  value       = var.enabled ? aws_launch_template.gitlab-runner[0].id : null
}

output "launch_template_version" {
  description = "Version of the launch template used by the autoscaling group"
  value       = var.enabled ? aws_launch_template.gitlab-runner[0].latest_version : null
}

output "manager_instance_id" {
  description = "Instance ID of the GitLab Runner manager"
  value       = var.enabled && var.create_manager && var.auth_token != null ? aws_instance.gitlab_runner[0].id : null
}

output "manager_instance_private_ip" {
  description = "Private IP address of the GitLab Runner manager instance"
  value       = var.enabled && var.create_manager && var.auth_token != null ? aws_instance.gitlab_runner[0].private_ip : null
}

output "s3_cache_bucket_name" {
  description = "Name of the S3 cache bucket"
  value       = var.enabled && var.enable_s3_cache ? aws_s3_bucket.s3_cache[0].id : null
}

output "s3_cache_bucket_arn" {
  description = "ARN of the S3 cache bucket"
  value       = var.enabled && var.enable_s3_cache ? aws_s3_bucket.s3_cache[0].arn : null
}

output "iam_role_name" {
  description = "Name of the IAM role for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_role.gitlab-runner-manager-role[0].name : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_role.gitlab-runner-manager-role[0].arn : null
}

output "iam_policy_name" {
  description = "Name of the IAM policy for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_policy.gitlab-runner-manager-policy[0].name : null
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_policy.gitlab-runner-manager-policy[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_instance_profile.gitlab-runner-manager-profile[0].name : null
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile for the GitLab Runner manager"
  value       = var.enabled && var.create_manager ? aws_iam_instance_profile.gitlab-runner-manager-profile[0].arn : null
}