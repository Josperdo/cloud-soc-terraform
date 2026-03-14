terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Credentials are read from ~/.aws/credentials (set via `aws configure`).
  # Do not hardcode keys here — use environment variables or the credentials
  # file. See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

  default_tags {
    tags = local.common_tags
  }
}
