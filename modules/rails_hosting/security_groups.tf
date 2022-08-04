resource "aws_security_group" "web_public" {
  name        = "${local.prefix}-web-public"
  description = "Allow inbound public web traffic."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
    Name = "${local.prefix}-web-public"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "web_private" {
  name        = "${local.prefix}-web-privaye"
  description = "Allows traffic within the VPC to reach the web tier."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP traffic."
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_public.id]
    self            = true
  }

  ingress {
    description     = "Allow HTTPS traffic."
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_public.id]
    self            = true
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-web-private"
  }
}

resource "aws_security_group" "db_access" {
  name        = "${local.prefix}-db-access"
  description = "Allow access to the database cluster."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow access from the web tier."
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    self            = true
    security_groups = [aws_security_group.web_private.id]
  }

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-db-access"
  }
}
