variable "friendly_name_prefix" {
  type        = string
  description = "(Optional) Friendly name prefix used for tagging and naming AWS resources."
  default = "tfe-deployment-aws-standalone-external-services"
}

# Network
variable "network_cidr" {
  type        = string
  description = "(Optional) CIDR block for VPC."
  default     = "10.0.0.0/16"
}

variable "network_private_subnet_cidrs" {
  type        = list(string)
  description = "(Optional) List of private subnet CIDR ranges to create in VPC."
  default     = ["10.0.32.0/20", "10.0.48.0/20"]
}

variable "network_public_subnet_cidrs" {
  type        = list(string)
  description = "(Optional) List of public subnet CIDR ranges to create in VPC."
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
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

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  azs                            = data.aws_availability_zones.available.names
  cidr                           = var.network_cidr
  create_igw                     = true
  default_security_group_egress  = []
  default_security_group_ingress = []
  enable_dns_hostnames           = true
  enable_dns_support             = true
  enable_nat_gateway             = true
  manage_default_security_group  = true
  map_public_ip_on_launch        = true
  name                           = "${var.friendly_name_prefix}-tfe-vpc"
  one_nat_gateway_per_az         = false
  private_subnets                = var.network_private_subnet_cidrs
  public_subnets                 = var.network_public_subnet_cidrs
  single_nat_gateway             = false

  igw_tags = {
    Name = "${var.friendly_name_prefix}-tfe-igw"
  }
  nat_eip_tags = {
    Name = "${var.friendly_name_prefix}-tfe-nat-eip"
  }
  nat_gateway_tags = {
    Name = "${var.friendly_name_prefix}-tfe-tgw"
  }
  private_route_table_tags = {
    Name = "${var.friendly_name_prefix}-tfe-rtb-private"
  }
  private_subnet_tags = {
    Name = "${var.friendly_name_prefix}-private"
  }
  public_route_table_tags = {
    Name = "${var.friendly_name_prefix}-tfe-rtb-public"
  }
  public_subnet_tags = {
    Name = "${var.friendly_name_prefix}-public"
  }
  vpc_tags = {
    Name = "${var.friendly_name_prefix}-tfe-vpc"
  }
}

resource "aws_security_group" "ssm" {
  description = "The security group of Systems Manager for TFE."
  name        = "${var.friendly_name_prefix}-tfe"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 443
    protocol  = "tcp"
    to_port   = 443

    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    description = "Allow the ingress of HTTPS traffic from all private subnets."
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.0"

  security_group_ids = [aws_security_group.ssm.id]
  vpc_id             = module.vpc.vpc_id

  endpoints = {
    ec2 = {
      service             = "ec2"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    ec2messages = {
      private_dns_enabled = true
      service             = "ec2messages"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      
      tags = {
        Name = "${var.friendly_name_prefix}-tfe-ec2messages-vpc-endpoint"

      }
    }
    kms = {
      service             = "kms"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    s3 = {
      route_table_ids = module.vpc.private_route_table_ids
      service         = "s3"
      service_type    = "Gateway"

      tags = {
        Name = "${var.friendly_name_prefix}-tfe-s3-vpc-endpoint"
      }
    }
    ssm = {
      private_dns_enabled = true
      service             = "ssm"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets

      tags = {
        Name = "${var.friendly_name_prefix}-tfe-ssm-vpc-endpoint"
      }
    }
    ssmmessages = {
      private_dns_enabled = true
      service             = "ssmmessages"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets

      tags = {
        Name = "${var.friendly_name_prefix}-tfe-ssmmessages-vpc-endpoint"
      }
    }
  }
}

data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
