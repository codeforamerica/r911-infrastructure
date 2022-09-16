resource "aws_kms_key" "codepipeline" {
  description             = "Hosting encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = templatefile("${path.module}/templates/key-policy.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    region : var.region,
    bucket_arn : aws_s3_bucket.artifacts.arn,
  })
}

resource "aws_kms_alias" "codepipeline" {
  name          = "alias/${var.project}/${var.environment}/codepipeline"
  target_key_id = aws_kms_key.codepipeline.id
}
