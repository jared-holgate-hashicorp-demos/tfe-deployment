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
    cidr_blocks = length(var.bastion_ip_restrictions) == 0 ? ["0.0.0.0/0"] : var.bastion_ip_restrictions
  }

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-security-group"
  }
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
    cidr_blocks = var.network_public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = var.network_public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8800
    to_port     = 8800
    cidr_blocks = var.network_public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = var.network_public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.network_public_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = var.network_private_subnet_cidrs
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
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = length(var.tfe_ip_restrictions) == 0 ? ["0.0.0.0/0"] : var.tfe_ip_restrictions
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8800
    to_port     = 8800
    cidr_blocks = length(var.replicated_ip_restrictions) == 0 ? ["0.0.0.0/0"] : var.replicated_ip_restrictions
  }

    ingress {
    protocol    = "tcp"
    from_port   = 9091
    to_port     = 9091
    cidr_blocks = length(var.replicated_ip_restrictions) == 0 ? ["0.0.0.0/0"] : var.replicated_ip_restrictions
  }

  tags = {
    Name = "${var.friendly_name_prefix}-alb-security-group"
  }
}

resource "aws_security_group" "rds" {
  name   = "${var.friendly_name_prefix}-rds-security-group"
  vpc_id = aws_vpc.main.id

  egress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = var.network_private_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = var.network_private_subnet_cidrs
  }

  tags = {
    Name = "${var.friendly_name_prefix}-rds-security-group"
  }
}

resource "aws_security_group" "redis" {
  description = "The security group of the Redis deployment for TFE."
  name        = "${var.friendly_name_prefix}-redis-security-group"
  vpc_id      = aws_vpc.main.id

  egress {
    protocol    = "tcp"
    from_port   = 6379
    to_port     = 6379
    cidr_blocks = var.network_private_subnet_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 6379
    to_port     = 6379
    cidr_blocks = var.network_private_subnet_cidrs
  }

  tags = {
    Name = "${var.friendly_name_prefix}-redis-security-group"
  }
}