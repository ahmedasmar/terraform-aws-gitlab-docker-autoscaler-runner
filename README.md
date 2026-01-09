# Terraform AWS GitLab Docker Autoscaler Runner

A Terraform module for deploying GitLab Runner with Docker Autoscaler on AWS. This module creates an Auto Scaling Group (ASG) with Spot instances optimized for CI/CD workloads.

## Features

- **Attribute-Based Instance Selection** (default): Automatically selects from a pool of instance types based on requirements, improving Spot availability and reducing interruptions
- **Spot Instance Optimization**: Configured with `price-capacity-optimized` allocation strategy for best price/availability balance
- **S3 Cache Support**: Optional S3 bucket for GitLab Runner cache with configurable expiration
- **Flexible Architecture**: Supports both x86_64 (Intel/AMD) and ARM64 (Graviton) instances
- **Cost Optimization**: Burstable instances included by default for cost-effective CI/CD jobs

## Usage

### Basic Example

```hcl
module "gitlab_runner" {
  source  = "ahmedasmar/gitlab-docker-autoscaler-runner/aws"
  version = "~> 1.0"

  auth_token   = var.gitlab_runner_token
  asg_max_size = 10
  asg_subnets  = ["subnet-xxx", "subnet-yyy"]

  tags = {
    Environment = "production"
  }
}
```

### Advanced Example

```hcl
module "gitlab_runner" {
  source  = "ahmedasmar/gitlab-docker-autoscaler-runner/aws"
  version = "~> 1.0"

  auth_token   = var.gitlab_runner_token
  asg_max_size = 10
  asg_subnets  = ["subnet-xxx", "subnet-yyy"]

  # Customize instance selection
  vcpu_count_min = 2
  vcpu_count_max = 4
  memory_mib_min = 8192
  memory_mib_max = 16384

  # Restrict to specific architectures
  # cpu_manufacturers = ["amazon-web-services"]  # ARM64/Graviton only
  # cpu_manufacturers = ["intel", "amd"]         # x86_64 only

  # Exclude burstable instances for consistent performance
  # burstable_performance = "excluded"

  tags = {
    Environment = "production"
  }
}
```

## Attribute-Based Instance Selection

This module uses **attribute-based instance selection** by default, which is the AWS-recommended approach for Spot instances. Instead of specifying a single instance type, you define requirements (vCPUs, memory, etc.), and AWS selects from all matching instance types.

### Benefits

- **Higher Spot availability**: More instance types = larger capacity pool
- **Lower interruption rates**: AWS can shift to available capacity
- **Better pricing**: Access to the cheapest available instances meeting your requirements

### Default Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `allowed_instance_types` | `["c*", "m*", "r*"]` | Compute, general purpose, and memory optimized families |
| `excluded_instance_types` | `[]` | Empty by default; add patterns to exclude specific types |
| `burstable_performance` | `"included"` | Includes T-series for cost-effective short-lived jobs |
| `cpu_manufacturers` | `["intel", "amd", "amazon-web-services"]` | All architectures (match with your AMI) |
| `instance_generations` | `["current"]` | Latest generation for best price/performance |
| `local_storage` | `"included"` | Allows instance store variants (c6gd, m5d, etc.) |
| `local_storage_types` | `["ssd"]` | SSD only for faster I/O |
| `accelerator_count_max` | `0` | Excludes GPU/accelerator instances |

### Using Specific Instance Type

To use a specific instance type instead of attribute-based selection:

```hcl
module "gitlab_runner" {
  source  = "ahmedasmar/gitlab-docker-autoscaler-runner/aws"
  version = "~> 1.0"

  use_attribute_based_instance_selection = false
  asg_runners_ec2_type                   = "m5.large"

  # ... other required variables
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `asg_max_size` | Maximum number of runner instances | `number` |
| `asg_subnets` | Subnet IDs for runner instances | `list(string)` |

### Optional - General

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enabled` | Enable or disable the module | `bool` | `true` |
| `auth_token` | GitLab runner authentication token | `string` | `null` |
| `name_prefix` | Prefix for resource names | `string` | `""` |
| `create_manager` | Create GitLab runner manager EC2 instance | `bool` | `true` |
| `manager_ec2_type` | Manager instance type | `string` | `"t4g.small"` |
| `manager_ami_ssm_parameter_name` | SSM parameter name with the manager AMI ID. When null, auto-selects AL2023 parameter based on manager EC2 architecture | `string` | `null` |
| `asg_runners_ami` | AMI for runner instances (must have Docker) | `string` | `null` |
| `enable_s3_cache` | Enable S3 cache bucket | `bool` | `true` |
| `s3_cache_expiration_days` | S3 cache object expiration | `number` | `30` |
| `capacity_per_instance` | Concurrent jobs per instance | `number` | `1` |
| `vpc_id` | VPC ID (optional) | `string` | `""` |
| `tags` | Tags to add to instances | `map(string)` | `{}` |
| `default_tags` | Default tags applied via AWS provider | `map(string)` | `{}` |

### Optional - Security

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `asg_security_groups` | Security groups for autoscaled runners | `list(string)` | `null` |
| `manager_security_groups` | Security groups for manager instance | `list(string)` | `null` |
| `asg_iam_instance_profile` | IAM instance profile for autoscaled runners | `string` | `null` |
| `extra_policy_entries` | Extra entries to add to IAM policy | `map(any)` | `null` |

### Optional - Instance Selection

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `use_attribute_based_instance_selection` | Use attribute-based selection (recommended for Spot) | `bool` | `true` |
| `asg_runners_ec2_type` | Specific instance type (when not using attribute-based) | `string` | `null` |
| `vcpu_count_min` | Minimum vCPUs | `number` | `2` |
| `vcpu_count_max` | Maximum vCPUs | `number` | `4` |
| `memory_mib_min` | Minimum memory (MiB) | `number` | `8192` |
| `memory_mib_max` | Maximum memory (MiB) | `number` | `16384` |
| `allowed_instance_types` | Instance type patterns to allow | `list(string)` | `["c*", "m*", "r*"]` |
| `excluded_instance_types` | Instance type patterns to exclude | `list(string)` | `[]` |
| `accelerator_count_max` | Max accelerator count (0 = no GPUs) | `number` | `0` |
| `burstable_performance` | Burstable instance handling | `string` | `"included"` |
| `cpu_manufacturers` | CPU manufacturers (architecture control) | `list(string)` | `["intel", "amd", "amazon-web-services"]` |
| `instance_generations` | Instance generations | `list(string)` | `["current"]` |
| `local_storage` | Local storage preference | `string` | `"included"` |
| `local_storage_types` | Local storage types | `list(string)` | `["ssd"]` |
| `network_bandwidth_gbps_max` | Max network bandwidth (Gbps) | `number` | `null` |

### Optional - Spot Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `on_demand_percentage_above_base_capacity` | On-demand percentage (0 = all Spot) | `number` | `0` |
| `spot_allocation_strategy` | Spot allocation strategy | `string` | `"price-capacity-optimized"` |

## Outputs

| Name | Description |
|------|-------------|
| `autoscaling_group_name` | Name of the GitLab Runner autoscaling group |
| `autoscaling_group_arn` | ARN of the GitLab Runner autoscaling group |
| `launch_template_id` | ID of the launch template |
| `launch_template_version` | Version of the launch template |
| `manager_instance_id` | Instance ID of the GitLab Runner manager |
| `manager_instance_private_ip` | Private IP of the manager instance |
| `s3_cache_bucket_name` | Name of the S3 cache bucket |
| `s3_cache_bucket_arn` | ARN of the S3 cache bucket |
| `iam_role_name` | Name of the manager IAM role |
| `iam_role_arn` | ARN of the manager IAM role |
| `iam_policy_name` | Name of the manager IAM policy |
| `iam_policy_arn` | ARN of the manager IAM policy |
| `iam_instance_profile_name` | Name of the manager IAM instance profile |
| `iam_instance_profile_arn` | ARN of the manager IAM instance profile |

## Architecture Considerations

When using attribute-based instance selection, ensure your `cpu_manufacturers` setting matches your AMI architecture:

- **x86_64 AMI**: Set `cpu_manufacturers = ["intel", "amd"]`
- **ARM64 AMI**: Set `cpu_manufacturers = ["amazon-web-services"]`
- **Multi-arch**: Keep default (but ensure AMI supports both)

## Requirements

| Name | Version |
|------|---------|
| [terraform](https://www.terraform.io/) | >= 1.9 |
| [aws](https://registry.terraform.io/providers/hashicorp/aws/latest) | >= 5.72 |
| [random](https://registry.terraform.io/providers/hashicorp/random/latest) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| [aws](https://registry.terraform.io/providers/hashicorp/aws/latest) | >= 5.72 |
| [random](https://registry.terraform.io/providers/hashicorp/random/latest) | >= 3.0 |

## Breaking Changes

### S3 Cache Lifecycle Configuration

The S3 cache bucket lifecycle rule now uses an empty `filter {}` block instead of the deprecated `prefix` argument. This is required for AWS provider >= 5.x. If you're upgrading from an older version, Terraform will recreate the lifecycle configuration.

### Attribute-Based Instance Selection (Default)

This module now defaults to `use_attribute_based_instance_selection = true`. If you were previously using a specific instance type, either:
1. Set `use_attribute_based_instance_selection = false` and specify `asg_runners_ec2_type`
2. Or migrate to attribute-based selection (recommended for Spot instances)

## License

[MIT](LICENSE)
