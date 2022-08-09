resource "aws_iam_policy" "pipeline" {
  name        = "${local.prefix}-code-pipeline"
  description = "Policy used in trust relationship with CodePipeline."

  policy = templatefile(
    "${path.module}/templates/code-pipeline-policy.json.tftpl",
    local.policy_vars
  )
}

resource "aws_iam_role" "pipeline" {
  name        = "${local.prefix}-code-pipeline"
  description = "Required access for the CI/CD pipeline."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.pipeline.arn,
  ]
}

resource "aws_iam_policy" "build" {
  name        = "${local.prefix}-code-build"
  description = "Policy used in trust relationship with CodePipeline."

  policy = templatefile(
    "${path.module}/templates/code-build-policy.json.tftpl",
    merge(local.policy_vars, {
      bucket_arn : aws_s3_bucket.artifacts.arn,
      ecr_arn : data.aws_ecr_repository.containers.arn,
      log_group_arns : [for group in aws_cloudwatch_log_group.logs : group.arn],
    })
  )
}

resource "aws_iam_policy" "migrate" {
  name        = "${local.prefix}-code-build-migrate"
  description = "Policy to allow access to required resources for running migrations."

  policy = templatefile(
    "${path.module}/templates/code-build-migrate-policy.json.tftpl",
    merge(local.policy_vars, {
      # The ARN includes the current revision. Remove it so that we can run any
      # version of the task.
      task_arn : replace(
        data.aws_ecs_task_definition.task.arn,
        "/:${data.aws_ecs_task_definition.task.revision}$/",
        ""
      ),
      role_arns : [
        var.task_execution_role,
        data.aws_ecs_task_definition.task.task_role_arn,
      ]
    })
  )
}

resource "aws_iam_policy" "build_vpc" {
  name        = "${local.prefix}-code-build-vpc"
  description = "Policy used in trust relationship with CodePipeline."

  policy = templatefile(
    "${path.module}/templates/code-build-vpc-policy.json.tftpl",
    merge(local.policy_vars, {
      subnet_arns : [
        for id in data.aws_subnets.private.ids :
        "arn:${data.aws_partition.current.partition}:ec2:${var.region}:${data.aws_caller_identity.identity.account_id}:subnet/${id}"
      ]
    })
  )
}

resource "aws_iam_role" "build" {
  name        = "${local.prefix}-code-build"
  description = "Required access for AWS CodeBuild."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.build.arn,
    aws_iam_policy.build_vpc.arn,
  ]
}

resource "aws_iam_role" "migrate" {
  name        = "${local.prefix}-code-build-migrate"
  description = "Required access for running migrations via AWS CodeBuild."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.build.arn,
    aws_iam_policy.migrate.arn,
    aws_iam_policy.build_vpc.arn,
  ]
}
