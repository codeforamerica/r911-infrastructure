resource "aws_s3_bucket" "config" {
  bucket = "${local.prefix}-config"

  lifecycle {
    prevent_destroy = true
  }
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
      kms_master_key_id = aws_kms_key.backend.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = templatefile("${path.module}/templates/bucket-policy.json.tftpl", {
    account : data.aws_caller_identity.identity.account_id
    partition : data.aws_partition.current.partition
    bucket : aws_s3_bucket.config.bucket
  })
}
