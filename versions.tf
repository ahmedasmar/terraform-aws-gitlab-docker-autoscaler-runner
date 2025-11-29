terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.72"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
