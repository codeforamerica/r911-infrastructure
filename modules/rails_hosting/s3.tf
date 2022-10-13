resource "aws_s3_bucket" "logs" {
  bucket        = "${local.prefix}-logs"
  force_destroy = var.force_delete

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      # We have to use AES256 here as some services don't support writing to s3
      # with a customer managed key (CMK).
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "logs" {
  bucket        = aws_s3_bucket.logs.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "${local.aws_logs_path}/s3accesslogs/${aws_s3_bucket.logs.id}"
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = templatefile("${path.module}/templates/bucket-policy-logs.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    bucket_arn : aws_s3_bucket.logs.arn,
    elb_account_arn : data.aws_elb_service_account.web.arn
  })
}

resource "aws_s3_bucket" "files" {
  bucket        = "${local.prefix}-files"
  force_destroy = var.force_delete

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "files" {
  bucket = aws_s3_bucket.files.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "files" {
  bucket = aws_s3_bucket.files.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "files" {
  bucket = aws_s3_bucket.files.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.hosting.id
    }
  }
}

resource "aws_s3_bucket_versioning" "files" {
  bucket = aws_s3_bucket.files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "files" {
  bucket        = aws_s3_bucket.files.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "${local.aws_logs_path}/s3accesslogs/${aws_s3_bucket.files.id}"
}

resource "aws_s3_bucket_policy" "files" {
  bucket = aws_s3_bucket.files.id
  policy = templatefile("${path.module}/templates/bucket-policy-files.json.tftpl", {
    bucket_arn : aws_s3_bucket.files.arn,
  })
}
