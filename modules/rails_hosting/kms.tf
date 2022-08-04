resource "aws_kms_key" "hosting" {
  description             = "Hosting encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  policy = templatefile("${path.module}/templates/key-policy.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    region : var.region,
    bucket_arn : aws_s3_bucket.logs.arn,
    repository_name : "${local.prefix}-web",
  })
}

resource "aws_kms_alias" "hosting" {
  name          = "alias/${var.project}/${var.environment}/hosting"
  target_key_id = aws_kms_key.hosting.id
}
