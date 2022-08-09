locals {
  container_log_group = "/aws/ecs/${var.project}/${var.environment}/web"
  prefix              = "${var.project}-${var.environment}"
  rails_environment   = var.rails_environment != "" ? var.rails_environment : var.environment
  container_template_vars = {
    command : "null",
    environment_variables : var.environment_variables,
    db_secret_arn : aws_secretsmanager_secret.db_master.arn,
    image_repo : aws_ecr_repository.containers.repository_url,
    image_tag : var.image_tag,
    keybase_secret_arn : aws_ssm_parameter.web-keybase.arn,
    log_group : local.container_log_group,
    rails_environment : local.rails_environment,
    region : var.region,
  }

  # The task definition may be managed outside of terraform (such as by a CI/CD
  # pipeline). Make sure we know the latest version so that we can use it for
  # the service.
  web_task_arn = (
    data.aws_ecs_task_definition.web_latest.revision > aws_ecs_task_definition.web.revision
    ? data.aws_ecs_task_definition.web_latest.arn
    : aws_ecs_task_definition.web.arn
  )
}

data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_secretsmanager_random_password" "db_master" {
  password_length    = 32
  exclude_characters = "/\"@ '"
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

data "aws_elb_service_account" "web" {
  region = var.region
}

data "aws_ecs_task_definition" "web_latest" {
  task_definition = aws_ecs_task_definition.web.family
}

resource "random_id" "keybase" {
  byte_length = 64
}
