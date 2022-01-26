variable "friendly_name_prefix" {
  type        = string
  description = "(Optional) Friendly name prefix used for tagging and naming AWS resources."
  default = "jared-holgate-tfe-poc"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags {
   tags = {
     Environment = var.friendly_name_prefix
     Owner       = "Jared Holgate"
     Description     = "Test Environment for TFE"
   }
 }
}

provider "cloudflare" {

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

resource "aws_route_table" "internet" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.friendly_name_prefix}-internet-route-table"
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

resource "aws_route_table_association" "bastion" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.internet.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  provisioner "local-exec" { 
    command = "echo '${tls_private_key.main.private_key_pem}' > ./tfe.pem"
  }

  user_data = <<EOF
#!/bin/bash

privateKey="${tls_private_key.main.private_key_pem}"
echo "$privateKey" > tfe.pem
chmod 400 tfe.pem
EOF

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-server"
  }
}

resource "aws_security_group" "tfe" {
  name   = "${var.friendly_name_prefix}-tfe-security-group"
  vpc_id = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-security-group"
  }
}

resource "aws_network_interface" "tfe" {
  count = 2
  subnet_id   = aws_subnet.private.id
  private_ips = ["10.0.2.10${count.index}"]
  security_groups = [ aws_security_group.tfe.id ] 

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-network-interface-${count.index}"
  }
}

resource "aws_instance" "tfe" {
  count = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m5.xlarge"
  key_name      = aws_key_pair.main.key_name

  network_interface {
    network_interface_id = aws_network_interface.tfe[count.index].id
    device_index         = 0
  }

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index}"
  }
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "main"
  public_key = tls_private_key.main.public_key_openssh
}

resource "aws_security_group" "alb" {
  name   = "${var.friendly_name_prefix}-alb-security-group"
  vpc_id = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.friendly_name_prefix}-alb-security-group"
  }
}

resource "aws_lb" "tfe" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [ aws_subnet.public.id ]

  tags = {
    Name = "${var.friendly_name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "tfe" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${var.friendly_name_prefix}-alb-target-group"
  }
}

resource "aws_lb_target_group_attachment" "tfe" {
  count = 2
  target_group_arn = aws_lb_target_group.tfe.arn
  target_id        = aws_instance.tfe[count.index].id
  port             = 80
}

resource "aws_acm_certificate" "tfe" {
  domain_name       = "tfe.hashicorpdemo.net"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "cloudflare_zone" "tfe" {
  name = "hashicorpdemo.net"
}

resource "cloudflare_record" "tfe_cert" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_name
  value   = tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_value
  type    = tolist(aws_acm_certificate.tfe.domain_validation_options)[0].resource_record_type
  ttl     = 3600
}

resource "cloudflare_record" "tfe" {
  zone_id = data.cloudflare_zone.tfe.id
  name    = "tfe.hashicorpdemo.net"
  value   = aws_lb.tfe.dns_name
  type    = "CNAME"
  ttl     = 3600
}

resource "aws_lb_listener" "tfe" {
  load_balancer_arn = aws_lb.tfe.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.tfe.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe.arn
  }
}

