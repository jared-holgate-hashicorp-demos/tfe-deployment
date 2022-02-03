resource "aws_subnet" "public" {
  count                   = local.subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.network_public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "${var.friendly_name_prefix}-subnet-public-${count.index}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table_association" "bastion" {
  count          = local.subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.internet.id
}

resource "aws_subnet" "private" {
  count                = local.subnet_count
  vpc_id               = aws_vpc.main.id
  cidr_block           = var.network_private_subnet_cidrs[count.index]
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "${var.friendly_name_prefix}-subnet-private-${count.index}"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}