resource "aws_s3_bucket" "config" {
  bucket = "${local.prefix}-config"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "config" {
  bucket = aws_s3_bucket.config.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.security.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "config" {
  bucket        = aws_s3_bucket.config.id
  target_bucket = aws_s3_bucket.config.id
  target_prefix = "${local.aws_logs_path}/s3accesslogs/${aws_s3_bucket.config.id}"
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = templatefile("${path.module}/templates/bucket-policy.json.tftpl", {
    account : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    bucket : aws_s3_bucket.config.bucket,
    region : var.region,
    prefix : local.prefix,
  })
}
