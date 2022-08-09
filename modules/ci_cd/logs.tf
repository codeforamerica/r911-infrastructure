locals {
  log_groups = [
    "/aws/codebuild/${var.project}/${var.environment}/db-migrate",
    "/aws/codebuild/${var.project}/${var.environment}/web",
  ]
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each          = toset(local.log_groups)
  name              = each.value
  retention_in_days = var.log_retention
  kms_key_id        = aws_kms_key.codepipeline.arn
}
