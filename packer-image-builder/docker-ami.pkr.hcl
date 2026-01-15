data "amazon-parameterstore" "al2023_arm64" {
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
  region = "us-east-1"
}

source "amazon-ebs" "amazon-linux-docker" {
  ami_name      = "amazon-linux-docker-{{timestamp}}"
  instance_type = "t4g.small"
  region        = "us-east-1"
  source_ami    = data.amazon-parameterstore.al2023_arm64.value

  # SSM Session Manager for connectivity
  communicator  = "ssh"
  ssh_username  = "ec2-user"
  ssh_interface = "session_manager"

  # Temporary IAM role with AmazonSSMManagedInstanceCore permissions
  temporary_iam_instance_profile_policy_document {
    Version = "2012-10-17"
    Statement {
      Effect = "Allow"
      Action = [
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation"
      ]
      Resource = ["*"]
    }
    Statement {
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = ["*"]
    }
    Statement {
      Effect = "Allow"
      Action = [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ]
      Resource = ["*"]
    }
  }

  vpc_filter {
    filters = {
      "state" : "available"
    }
  }

  subnet_filter {
    filters = {
      "state" : "available"
    }
    random = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

build {
  sources = [
    "source.amazon-ebs.amazon-linux-docker"
  ]

  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install docker -y",
      "sudo usermod -a -G docker ec2-user",
      "sudo systemctl start docker",
      "sudo systemctl enable docker"
    ]
  }
}
