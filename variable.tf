variable "auth_token" {
  type        = string
  description = "Gitalb runner authentication token"
  default     = null
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Enable or disable the module and its resources"
}

variable "name_prefix" {
  type        = string
  description = "Optional suffix to make resource names unique per deployment"
  default     = ""
}

variable "default_tags" {
  description = "Map of default tags applied via the AWS provider to all supported resources"
  type        = map(string)
  default     = {}
}

variable "asg_max_size" {
  type        = number
  description = "Maximum size of instances"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
  default     = ""
}

variable "asg_subnets" {
  type        = list(string)
  description = "Subnets where to create autoscaled instances"
}

variable "create_manager" {
  type        = bool
  description = "Either to create gitlab runner docker autoscaller ec2 or not, If you disable this make sure to have self-host runner already running to configure with docker autoscaller auto scaling group"
  default     = true
}

variable "manager_ec2_type" {
  type        = string
  description = "Gitlab runner manager ec2 instance type"
  default     = "t2.small"
}

variable "asg_runners_ami" {
  type        = string
  description = "AMI used in ASG launch template to scale out runners, MUST HAVE DOCKER ENGINE INSTALLED"
  default     = null
}

variable "asg_runners_ec2_type" {
  type        = string
  description = "EC2 instance type for scaled out runners. Required when use_attribute_based_instance_selection is false. Must match AMI architecture."
  default     = null
  validation {
    condition     = var.asg_runners_ec2_type == null || can(regex("^[a-z][a-z0-9]*\\.[a-z0-9]+$", var.asg_runners_ec2_type))
    error_message = "asg_runners_ec2_type must be null or a valid EC2 instance type (e.g., m6i.medium, m7g.medium)"
  }
}

variable "asg_security_groups" {
  type        = list(string)
  description = "Security Groups of autoscaled runners"
  default     = null
}

variable "manager_security_groups" {
  type        = list(string)
  description = "Security Groups of gitlab manager runner"
  default     = null
}

variable "asg_iam_instance_profile" {
  type        = string
  description = "IAM instance profile (name or ARN) for autoscaled runners"
  default     = null
}

variable "enable_s3_cache" {
  type        = bool
  description = "Enable s3 cache or not"
  default     = true
}

variable "s3_cache_expiration_days" {
  type        = number
  description = "Number of days after which objects in the S3 cache bucket expire. Set to 0 to disable expiration."
  default     = 30
}

variable "capacity_per_instance" {
  type        = number
  description = "The number of jobs that can be executed concurrently by a single instance."
  default     = 1
}

variable "extra_policy_entries" {
  description = "Optional extra entries to add to the policy"
  type        = map(any)
  default     = null
}

variable "tags" {
  description = "A map of tags to add to instances"
  type        = map(string)
  default     = {}
}

# Instance Requirements for Attribute-Based Instance Selection
variable "use_attribute_based_instance_selection" {
  type        = bool
  description = "Use attribute-based instance selection instead of specific instance type. Recommended for Spot instances to improve availability and reduce interruptions."
  default     = true
}

variable "vcpu_count_min" {
  type        = number
  description = "Minimum number of vCPUs for attribute-based instance selection"
  default     = 2
  validation {
    condition     = var.vcpu_count_min >= 1
    error_message = "vcpu_count_min must be at least 1"
  }
}

variable "vcpu_count_max" {
  type        = number
  description = "Maximum number of vCPUs for attribute-based instance selection"
  default     = 4
  validation {
    condition     = var.vcpu_count_max >= 1
    error_message = "vcpu_count_max must be at least 1"
  }
  validation {
    condition     = var.vcpu_count_max >= var.vcpu_count_min
    error_message = "vcpu_count_max must be greater than or equal to vcpu_count_min"
  }
}

variable "memory_mib_min" {
  type        = number
  description = "Minimum memory in MiB for attribute-based instance selection"
  default     = 8192
  validation {
    condition     = var.memory_mib_min >= 512
    error_message = "memory_mib_min must be at least 512 MiB"
  }
}

variable "memory_mib_max" {
  type        = number
  description = "Maximum memory in MiB for attribute-based instance selection"
  default     = 16384
  validation {
    condition     = var.memory_mib_max >= 512
    error_message = "memory_mib_max must be at least 512 MiB"
  }
  validation {
    condition     = var.memory_mib_max >= var.memory_mib_min
    error_message = "memory_mib_max must be greater than or equal to memory_mib_min"
  }
}

variable "allowed_instance_types" {
  type        = list(string)
  description = "List of instance type patterns to allow. Defaults to compute-optimized, general-purpose, and memory-optimized families suited for CI/CD workloads."
  default     = ["c*", "m*", "r*"]
}

variable "excluded_instance_types" {
  type        = list(string)
  description = "List of instance type patterns to exclude from attribute-based selection. Empty by default to allow all types matching allowed_instance_types."
  default     = []
}

variable "accelerator_count_max" {
  type        = number
  description = "Optional maximum accelerator count. Set to 0 to exclude GPU/accelerator types; set to null to allow accelerators."
  default     = 0
  validation {
    condition     = var.accelerator_count_max == null || var.accelerator_count_max >= 0
    error_message = "accelerator_count_max must be null or a non-negative number"
  }
}

variable "burstable_performance" {
  type        = string
  description = "Burstable performance setting (included, excluded, required). Included by default for cost-effective short-lived CI/CD jobs."
  default     = "included"
  validation {
    condition     = contains(["included", "excluded", "required"], var.burstable_performance)
    error_message = "burstable_performance must be one of: included, excluded, required"
  }
}

variable "cpu_manufacturers" {
  type        = list(string)
  description = "List of CPU manufacturers to allow (intel, amd, amazon-web-services). Use intel/amd for x86_64, amazon-web-services for ARM64/Graviton. Should match your AMI architecture."
  default     = ["intel", "amd", "amazon-web-services"]
  validation {
    condition     = alltrue([for m in var.cpu_manufacturers : contains(["intel", "amd", "amazon-web-services"], m)])
    error_message = "cpu_manufacturers must contain only 'intel', 'amd', or 'amazon-web-services'"
  }
}

variable "instance_generations" {
  type        = list(string)
  description = "Instance generations to include (current or previous)"
  default     = ["current"]
  validation {
    condition     = alltrue([for gen in var.instance_generations : contains(["current", "previous"], gen)])
    error_message = "instance_generations must contain only 'current' or 'previous'"
  }
}

variable "local_storage_types" {
  type        = list(string)
  description = "List of local storage types to allow (hdd, ssd). SSD recommended for CI/CD workloads."
  default     = ["ssd"]
  validation {
    condition     = alltrue([for t in var.local_storage_types : contains(["hdd", "ssd"], t)])
    error_message = "local_storage_types must contain only 'hdd' or 'ssd'"
  }
}

variable "local_storage" {
  type        = string
  description = "Local storage preference for attribute-based selection (included, excluded, required). Set to included to allow instance store variants (c6gd, m5d, etc.) for potentially better Spot availability."
  default     = "included"
  validation {
    condition     = contains(["included", "excluded", "required"], var.local_storage)
    error_message = "local_storage must be one of: included, excluded, required"
  }
}

variable "network_bandwidth_gbps_max" {
  type        = number
  description = "Optional cap on network bandwidth (Gbps) in attribute-based selection. Set to null to allow any bandwidth."
  default     = null
  validation {
    condition     = var.network_bandwidth_gbps_max == null || var.network_bandwidth_gbps_max > 0
    error_message = "network_bandwidth_gbps_max must be null or greater than 0"
  }
}

variable "on_demand_percentage_above_base_capacity" {
  type        = number
  description = "Percentage of on-demand instances above base capacity (0-100). Set to 0 for all spot instances."
  default     = 0
  validation {
    condition     = var.on_demand_percentage_above_base_capacity >= 0 && var.on_demand_percentage_above_base_capacity <= 100
    error_message = "on_demand_percentage_above_base_capacity must be between 0 and 100"
  }
}

variable "spot_allocation_strategy" {
  type        = string
  description = "Spot allocation strategy (lowest-price, capacity-optimized, price-capacity-optimized)"
  default     = "price-capacity-optimized"
  validation {
    condition     = contains(["lowest-price", "capacity-optimized", "price-capacity-optimized"], var.spot_allocation_strategy)
    error_message = "spot_allocation_strategy must be one of: lowest-price, capacity-optimized, price-capacity-optimized"
  }
}
