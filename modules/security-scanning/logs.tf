locals {
  log_groups = [
    "/aws/cloudtrail",
  ]
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each          = toset(local.log_groups)
  name              = each.value
  retention_in_days = var.log_retention
  kms_key_id        = aws_kms_key.security.arn
}
