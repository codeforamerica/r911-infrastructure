resource "aws_s3_bucket" "etl" {
  bucket = "${local.prefix}-etl"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "etl" {
  bucket = aws_s3_bucket.etl.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "etl" {
  bucket = aws_s3_bucket.etl.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "etl" {
  bucket = aws_s3_bucket.etl.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.encryption_key
    }
  }
}

resource "aws_s3_bucket_versioning" "etl" {
  bucket = aws_s3_bucket.etl.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "etl" {
  bucket        = aws_s3_bucket.etl.id
  target_bucket = var.logging_bucket
  target_prefix = "${local.aws_logs_path}/s3accesslogs/${aws_s3_bucket.etl.id}"
}
