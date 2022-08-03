data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "backend" {
  description             = "Terraform backend encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  policy = templatefile("${path.module}/templates/key-policy.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    bucket_arn : aws_s3_bucket.terraform_state.arn
  })
}

resource "aws_kms_alias" "backend" {
  name          = "alias/${var.project}/${var.environment}/backend"
  target_key_id = aws_kms_key.backend.id
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket" {
  value = aws_s3_bucket.terraform_state.id
}
