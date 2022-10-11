locals {
  prefix = "${var.project}-${var.environment}"
}

data "aws_region" "current" {}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:use"
    values = ["private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:use"
    values = ["public"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

data "aws_security_group" "default" {
  vpc_id = var.vpc_id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}

data "aws_secretsmanager_random_password" "admin" {
  password_length    = 64
  exclude_characters = "/\"@ '\\"
}

resource "aws_vpc_endpoint" "redshift" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.redshift"
  vpc_endpoint_type = "Interface"
  subnet_ids        = data.aws_subnets.private.ids

  tags = {
    Name = "${local.prefix}-redshift"
  }
}
