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
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
    name = "ecs-decrypt-secret"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "kms:Decrypt",
            "ssm:GetParameter",
            "ssm:GetParameters"
          ]
          Resource = [
            aws_secretsmanager_secret.db_master.arn,
            aws_kms_key.hosting.arn,
            aws_ssm_parameter.web-keybase.arn
          ]
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchFullAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMFullAccess",
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
