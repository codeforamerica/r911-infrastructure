locals {
  prefix = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "backend" {
  description             = "Security encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  policy = templatefile("${path.module}/templates/key-policy.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    bucket_arn : aws_s3_bucket.config.arn
  })
}

resource "aws_kms_alias" "backend" {
  name          = "alias/${var.project}/${var.environment}/security"
  target_key_id = aws_kms_key.backend.id
}



resource "aws_securityhub_account" "account" {}

resource "aws_securityhub_standards_subscription" "aws" {
  depends_on    = [aws_securityhub_account.account]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.account]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}
