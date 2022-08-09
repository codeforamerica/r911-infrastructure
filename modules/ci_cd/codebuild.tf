resource "aws_codebuild_project" "web" {
  name         = "${local.prefix}-web"
  description  = "${var.project}: web (${var.environment})"
  service_role = aws_iam_role.build.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.artifacts.bucket}/cache"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "REPOSITORY_URL"
      type  = "PLAINTEXT"
      value = data.aws_ecr_repository.containers.repository_url
    }

    environment_variable {
      name  = "TAG"
      type  = "PLAINTEXT"
      value = "latest"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  vpc_config {
    security_group_ids = [aws_security_group.codebuild.id]
    subnets            = data.aws_subnets.private.ids
    vpc_id             = var.vpc_id
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = "/aws/codebuild/${var.project}/${var.environment}/web"
    }
  }
}

resource "aws_codebuild_project" "db_migrate" {
  name         = "${local.prefix}-db-migrate"
  description  = "${var.project}: database migrations (${var.environment})"
  service_role = aws_iam_role.migrate.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.artifacts.bucket}/cache"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile("${path.module}/templates/buildspec.yml.tftpl", {
      cluster_name : var.cluster_name
      task_definition : var.task_task_definition
      subnets : join(",", data.aws_subnets.private.ids)
      security_groups : aws_security_group.codebuild.id
    })
  }

  vpc_config {
    security_group_ids = [aws_security_group.codebuild.id]
    subnets            = data.aws_subnets.private.ids
    vpc_id             = var.vpc_id
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = "/aws/codebuild/${var.project}/${var.environment}/db-migrate"
    }
  }
}
