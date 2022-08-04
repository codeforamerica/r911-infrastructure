locals {
  prefix = "${var.project}-${var.environment}"
  azs    = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = {
    Name = local.prefix
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  count             = var.availability_zones
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${0 + (16 * count.index)}.0/20"
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.prefix}-public-${local.azs[count.index]}"
    use  = "public"
  }
}

resource "aws_route_table" "public" {
  count  = var.availability_zones
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${local.prefix}-public-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.availability_zones
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_subnet" "private" {
  count             = var.availability_zones
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${128 + (16 * count.index)}.0/20"
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.prefix}-private-${local.azs[count.index]}"
    use  = "private"
  }
}

resource "aws_route_table" "private" {
  count  = var.availability_zones
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${local.prefix}-private-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.availability_zones
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [
    for rt in aws_route_table.private :
    rt.id
  ]

  tags = {
    Name = "${local.prefix}-s3"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    for s in aws_subnet.private :
    s.id
  ]

  tags = {
    Name = "${local.prefix}-ssm"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "nat_gateway_ip" {
  count = var.single_nat_gateway ? 1 : var.availability_zones
  vpc   = true

  tags = {
    Name = "${local.prefix}-nat-${aws_subnet.public[count.index].availability_zone}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count             = var.single_nat_gateway ? 1 : var.availability_zones
  connectivity_type = "public"
  subnet_id         = aws_subnet.public[count.index].id
  allocation_id     = aws_eip.nat_gateway_ip[count.index].id

  tags = {
    Name = "${local.prefix}-public-${aws_subnet.public[count.index].availability_zone}"
  }
}

output "azs" {
  value = data.aws_availability_zones.available
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}
