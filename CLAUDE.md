# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform module that creates a GitLab Runner Docker autoscaler infrastructure on AWS. The module provisions:

- **Manager Instance**: An EC2 instance running GitLab Runner in Docker Autoscaler mode
- **Auto Scaling Group**: Dynamically scales runner instances based on job demand
- **Launch Template**: Configuration for spot instances that run GitLab CI/CD jobs
- **IAM Resources**: Roles, policies, and instance profiles for proper permissions
- **S3 Cache** (optional): Shared cache bucket for GitLab Runner jobs with configurable lifecycle

## Architecture

The module follows a two-tier architecture:
1. **Manager Tier**: Single EC2 instance (`aws_instance.gitlab_runner`) that coordinates job distribution
2. **Worker Tier**: Auto Scaling Group (`aws_autoscaling_group.gitlab_runners`) that provisions on-demand runner instances

Key architectural decisions:
- Uses spot instances for cost optimization
- Protects ASG from scale-in to prevent job interruption
- Manager instance uses latest Amazon Linux 2023, workers use ECS-optimized AMI
- IAM policies follow least-privilege principle with resource-specific permissions

## Key Variables

Essential configuration variables in `variable.tf`:
- `auth_token`: GitLab Runner authentication token (required for manager creation)
- `asg_max_size`: Maximum number of runner instances
- `asg_subnets`: VPC subnets for instance placement
- `create_manager`: Toggle manager instance creation (allows external manager)
- `enable_s3_cache`: Enable S3 shared cache (default: true)
- `capacity_per_instance`: Concurrent jobs per runner instance (affects total capacity calculation)

## File Structure

- `main.tf`: Core AWS resources (IAM, ASG, Launch Template, EC2, S3)
- `variable.tf`: Input variables with validation and defaults  
- `outputs.tf`: Module outputs for integration with other infrastructure
- `locals.tf`: Computed values and resource naming logic
- `data.tf`: AWS data sources for AMI lookup and account info
- `user-data/manager-user-data.sh.tftpl`: Bootstrap script for manager instance
- `policies/instance-docker-autoscaler-policy.json.tftpl`: IAM policy template

## Terraform Commands

Standard Terraform workflow:
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Configuration Notes

- The module supports multiple deployments via `name_prefix` variable
- S3 cache lifecycle is configurable via `s3_cache_expiration_days`
- Manager instance AMI is pinned but ignored in lifecycle to prevent replacement
- ASG desired capacity is managed by GitLab Runner, not Terraform
- Worker instances require Docker pre-installed (uses ECS-optimized AMI by default)

## Template Files

Two key template files use Terraform's `templatefile()` function:
1. `user-data/manager-user-data.sh.tftpl`: Configures GitLab Runner on manager instance
2. `policies/instance-docker-autoscaler-policy.json.tftpl`: Generates IAM permissions dynamically

Both templates receive variables from `locals.tf` for environment-specific configuration.