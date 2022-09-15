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
