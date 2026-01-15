data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ec2_instance_type" "manager" {
  count         = var.enabled && var.create_manager ? 1 : 0
  instance_type = var.manager_ec2_type
}

data "aws_subnet" "asg" {
  for_each = var.enabled && local.create_security_group && (var.vpc_id == null || var.vpc_id == "") ? toset(var.asg_subnets) : []
  id       = each.value
}

data "aws_ssm_parameter" "manager_ami" {
  count = var.enabled && var.create_manager ? 1 : 0
  name  = local.manager_ami_ssm_parameter_name_effective
}

data "aws_ami" "latest_amazon_ecs_linux_2023" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-2023.*-6.1-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  most_recent = true
}
