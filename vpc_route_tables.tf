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

resource "aws_route_table" "private" {
  count  = local.subnet_count
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw[count.index].id
  }

  tags = {
    Name = "${var.friendly_name_prefix}-nat-route-table-${count.index}"
  }
}