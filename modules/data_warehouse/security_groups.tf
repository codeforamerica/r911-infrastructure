resource "aws_security_group" "warehouse_public" {
  name_prefix = "${local.prefix}-data-warehouse-public-"
  description = "Allow inbound public traffic to the data warehouse."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Redshift traffic."
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    #tfsec:ignore:aws-ec2-no-public-ingress-sgr
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-data-warehouse-public"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "warehouse_private" {
  name_prefix = "${local.prefix}-data-warehouse-private"
  description = "Allows traffic within the VPC to reach the data warehouse."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Redshift traffic."
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [for s in data.aws_subnet.public : s.cidr_block]
    self        = true
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-data-warehouse-private"
  }

  lifecycle {
    create_before_destroy = true
  }
}
