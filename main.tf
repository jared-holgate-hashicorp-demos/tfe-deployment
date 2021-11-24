variable "vpc_name" {
    default = "tfe-deployment-aws-standalone-external-services"
}

terraform {
  backend "remote" {
    organization = "jaredfholgate-hashicorp"

    workspaces {
      name = "tfe-deployment-aws-standalone-external-services"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = var.vpc_name
  }
}