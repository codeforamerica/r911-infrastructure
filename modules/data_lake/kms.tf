resource "aws_kms_key" "data_lake" {
  description             = "Data lake encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = templatefile("${path.module}/templates/key-policy.json.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    environment : var.environment,
    project : var.project,
    region : var.region,
  })
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.project}/${var.environment}/data-lake"
  target_key_id = aws_kms_key.data_lake.id
}
