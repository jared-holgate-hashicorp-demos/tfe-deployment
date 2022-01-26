variable "friendly_name_prefix" {
  type        = string
  description = "(Optional) Friendly name prefix used for tagging and naming AWS resources."
  default = "jared-holgate-tfe-poc"
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
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_region" "current" {}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.friendly_name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.friendly_name_prefix}-gateway"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.friendly_name_prefix}-route-table"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.friendly_name_prefix}-subnet-public"
  }

  depends_on                = [aws_internet_gateway.main]
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "${var.friendly_name_prefix}-subnet-private"
  }
}

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

resource "aws_security_group" "bastion" {
  name   = "${var.friendly_name_prefix}-bastion-security-group"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-security-group"
  }
}

resource "aws_network_interface" "bastion" {
   subnet_id   = aws_subnet.public.id
   private_ips = ["10.0.1.101"]
   security_groups = [ aws_security_group.bastion.id ]
   
  tags = {
    Name = "${var.friendly_name_prefix}-bastion-network-interface"
  }
}

resource "aws_eip" "bastion" {
  vpc = true

  instance                  = aws_instance.bastion.id
  associate_with_private_ip = "10.0.1.101"
  depends_on                = [aws_internet_gateway.main]
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  

  network_interface {
    network_interface_id = aws_network_interface.bastion.id
    device_index         = 0
  }

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-server"
  }
}

resource "aws_network_interface" "tfe" {
  count = 2
  subnet_id   = aws_subnet.private.id
  private_ips = ["10.0.2.10${count.index}"]
   
  tags = {
    Name = "${var.friendly_name_prefix}-tfe-network-interface-${count.index}"
  }
}

resource "aws_instance" "tfe" {
  count = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m5.xlarge"

  network_interface {
    network_interface_id = aws_network_interface.tfe[count.index].id
    device_index         = 0
  }

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index}"
  }
}