data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_subnet" "asg" {
  for_each = var.enabled && local.create_security_group && (var.vpc_id == null || var.vpc_id == "") ? toset(var.asg_subnets) : []
  id       = each.value
}

data "aws_ami" "latest_amazon_linux_2023" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  most_recent = true
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
