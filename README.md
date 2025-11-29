# Terraform AWS GitLab Docker Autoscaler Runner

A Terraform module for deploying GitLab Runner with Docker Autoscaler on AWS. This module creates an Auto Scaling Group (ASG) with Spot instances optimized for CI/CD workloads.

## Features

- **Attribute-Based Instance Selection** (default): Automatically selects from a pool of instance types based on requirements, improving Spot availability and reducing interruptions
- **Spot Instance Optimization**: Configured with `price-capacity-optimized` allocation strategy for best price/availability balance
- **S3 Cache Support**: Optional S3 bucket for GitLab Runner cache with configurable expiration
- **Flexible Architecture**: Supports both x86_64 (Intel/AMD) and ARM64 (Graviton) instances

## Usage

```hcl
module "gitlab_runner" {
  source = "github.com/Hax7/terraform-aws-gitlab-docker-autoscaler-runner"

  auth_token   = var.gitlab_runner_token
  asg_max_size = 10
  asg_subnets  = ["subnet-xxx", "subnet-yyy"]

  # Optional: Customize instance selection
  vcpu_count_min = 2
  vcpu_count_max = 4
  memory_mib_min = 4096
  memory_mib_max = 8192

  # Optional: Restrict to specific architectures
  # cpu_manufacturers = ["amazon-web-services"]  # ARM64/Graviton only
  # cpu_manufacturers = ["intel", "amd"]         # x86_64 only

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
| `burstable_performance` | `"excluded"` | Excludes T-series to avoid CPU throttling |
| `cpu_manufacturers` | `["intel", "amd", "amazon-web-services"]` | All architectures (match with your AMI) |
| `instance_generations` | `["current"]` | Latest generation for best price/performance |
| `local_storage_types` | `["ssd"]` | SSD only for faster I/O |

### Using Specific Instance Type

To use a specific instance type instead of attribute-based selection:

```hcl
module "gitlab_runner" {
  source = "github.com/Hax7/terraform-aws-gitlab-docker-autoscaler-runner"

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
| `manager_ec2_type` | Manager instance type | `string` | `"t2.small"` |
| `asg_runners_ami` | AMI for runner instances (must have Docker) | `string` | `null` |
| `enable_s3_cache` | Enable S3 cache bucket | `bool` | `true` |
| `s3_cache_expiration_days` | S3 cache object expiration | `number` | `30` |
| `capacity_per_instance` | Concurrent jobs per instance | `number` | `1` |

### Optional - Instance Selection

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `use_attribute_based_instance_selection` | Use attribute-based selection (recommended for Spot) | `bool` | `true` |
| `asg_runners_ec2_type` | Specific instance type (when not using attribute-based) | `string` | `null` |
| `vcpu_count_min` | Minimum vCPUs | `number` | `2` |
| `vcpu_count_max` | Maximum vCPUs | `number` | `4` |
| `memory_mib_min` | Minimum memory (MiB) | `number` | `4096` |
| `memory_mib_max` | Maximum memory (MiB) | `number` | `8192` |
| `allowed_instance_types` | Instance type patterns to allow | `list(string)` | `["c*", "m*", "r*"]` |
| `burstable_performance` | Burstable instance handling | `string` | `"excluded"` |
| `cpu_manufacturers` | CPU manufacturers (architecture control) | `list(string)` | `["intel", "amd", "amazon-web-services"]` |
| `instance_generations` | Instance generations | `list(string)` | `["current"]` |
| `local_storage_types` | Local storage types | `list(string)` | `["ssd"]` |

### Optional - Spot Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `on_demand_percentage_above_base_capacity` | On-demand percentage (0 = all Spot) | `number` | `0` |
| `spot_allocation_strategy` | Spot allocation strategy | `string` | `"price-capacity-optimized"` |

## Architecture Considerations

When using attribute-based instance selection, ensure your `cpu_manufacturers` setting matches your AMI architecture:

- **x86_64 AMI**: Set `cpu_manufacturers = ["intel", "amd"]`
- **ARM64 AMI**: Set `cpu_manufacturers = ["amazon-web-services"]`
- **Multi-arch**: Keep default (but ensure AMI supports both)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.72 |

## Breaking Changes

### S3 Cache Lifecycle Configuration

The S3 cache bucket lifecycle rule now uses an empty `filter {}` block instead of the deprecated `prefix` argument. This is required for AWS provider >= 5.x. If you're upgrading from an older version, Terraform will recreate the lifecycle configuration.

### Attribute-Based Instance Selection (Default)

This module now defaults to `use_attribute_based_instance_selection = true`. If you were previously using a specific instance type, either:
1. Set `use_attribute_based_instance_selection = false` and specify `asg_runners_ec2_type`
2. Or migrate to attribute-based selection (recommended for Spot instances)

## License

MIT