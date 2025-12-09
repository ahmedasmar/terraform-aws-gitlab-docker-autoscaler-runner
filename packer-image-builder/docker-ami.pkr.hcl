data "amazon-parameterstore" "al2023_arm64" {
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
  region = "us-east-1"
}

source "amazon-ebs" "amazon-linux-docker" {
  ami_name      = "amazon-linux-docker-{{timestamp}}"
  instance_type = "t4g.small"
  region        = "us-east-1"
  subnet_id     = "subnet-06c0519eba0b0386c"
  source_ami    = data.amazon-parameterstore.al2023_arm64.value
  ssh_username  = "ec2-user"

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
