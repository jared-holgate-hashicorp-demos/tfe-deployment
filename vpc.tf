resource "aws_vpc" "main" {
  cidr_block           = var.network_cidr
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

resource "aws_eip" "nat" {
  count = local.subnet_count
  vpc   = true

  tags = {
    Name = "${var.friendly_name_prefix}-eip-nat-${count.index}"
  }
}

resource "aws_nat_gateway" "nat-gw" {
  count         = local.subnet_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "${var.friendly_name_prefix}-nat-${count.index}"
  }
}