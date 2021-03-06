terraform {
  required_version = "1.1.7"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnet_count = length(data.aws_availability_zones.available.zone_ids)
}
