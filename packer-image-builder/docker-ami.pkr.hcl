data "amazon-parameterstore" "al2023_arm64" {
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
  region = "us-east-1"
}

source "amazon-ebs" "amazon-linux-docker" {
  ami_name      = "amazon-linux-docker-{{timestamp}}"
  instance_type = "t4g.small"
  region        = "us-east-1"
  subnet_id     = "subnet-09be4c4c398901917"
  source_ami    = data.amazon-parameterstore.al2023_arm64.value
  ssh_username  = "ec2-user"
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
