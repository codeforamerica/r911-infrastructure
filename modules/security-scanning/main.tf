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

resource "aws_config_configuration_recorder" "config" {
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = aws_config_configuration_recorder.config.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.config]
}

resource "aws_config_delivery_channel" "config" {
  name           = "${local.prefix}-config"
  s3_bucket_name = aws_s3_bucket.config.bucket
  sns_topic_arn  = aws_sns_topic.config.arn

  snapshot_delivery_properties {
    delivery_frequency = var.config_delivery_frequency
  }

  depends_on = [aws_s3_bucket_policy.config]
}
