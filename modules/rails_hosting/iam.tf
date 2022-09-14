resource "aws_iam_policy" "web_secrets" {
  name        = "${local.prefix}-web-secrets"
  description = "Allows access to secrets for ${var.project} - ${var.environment}."

  policy = templatefile("${path.module}/templates/web-secrets-policy.json.tftpl", {
    db_credentials_arn : aws_secretsmanager_secret.db_master.arn,
    keybase_arn : aws_ssm_parameter.web-keybase.arn,
    kms_arn : aws_kms_key.hosting.arn,
  })
}

resource "aws_iam_policy" "web_files" {
  name        = "${local.prefix}-web-files"
  description = "Allows access to store and retrieve uploaded files for ${var.project} - ${var.environment}."

  policy = templatefile("${path.module}/templates/web-files-policy.json.tftpl", {
    bucket_arn : aws_s3_bucket.files.arn,
  })
}

resource "aws_iam_role" "web_execution" {
  name = "${local.prefix}-web-execution"

  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.web_secrets.arn,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "web_task" {
  name        = "${local.prefix}-web-task"
  description = "Allow ECS tasks to make calls to AWS services"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "ecs-send-email"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ses:SendEmail",
            "ses:SendRawEmail",
            "ses:SendTemplatedEmail"
          ]
          Resource = "*"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchFullAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMFullAccess",
    aws_iam_policy.web_files.arn,
    aws_iam_policy.web_secrets.arn,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "db_monitoring" {
  name        = "${local.prefix}-db-monitoring"
  description = "Enable monitoring for RDS."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole",
  ]

  lifecycle {
    create_before_destroy = true
  }
}
