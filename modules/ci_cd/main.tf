locals {
  # Get the UUID of the GitHub connection by parsing the ARN.
  connection_id = element(split("/", element(split(":", aws_codestarconnections_connection.github.id), length(split(":", aws_codestarconnections_connection.github.id)) - 1)), 1)

  policy_vars = {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    prefix : local.prefix,
    region : var.region,
  }
  prefix            = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_ecr_repository" "containers" {
  name = var.image_repository_name
}

data "aws_ecs_task_definition" "task" {
  task_definition = var.task_task_definition
}

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

resource "aws_security_group" "codebuild" {
  name        = "${local.prefix}-codebuild"
  description = "Allow access to VPC resources from AWS CodeBuild."
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-codebuild"
  }
}

resource "aws_codestarconnections_connection" "github" {
  name          = "${local.prefix}-github"
  provider_type = "GitHub"
}
