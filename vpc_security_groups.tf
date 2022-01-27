resource "aws_security_group" "bastion" {
  name   = "${var.friendly_name_prefix}-bastion-security-group"
  vpc_id = aws_vpc.main.id

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

locals {
    public_subnet_cidrs = [for index in range(3) : "10.0.${index}.0/24"]
}

resource "aws_security_group" "tfe" {
  name   = "${var.friendly_name_prefix}-tfe-security-group"
  vpc_id = aws_vpc.main.id

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
    cidr_blocks = local.public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = local.public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = local.public_subnet_cidrs
  }

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-security-group"
  }
}

resource "aws_security_group" "alb" {
  name   = "${var.friendly_name_prefix}-alb-security-group"
  vpc_id = aws_vpc.main.id

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