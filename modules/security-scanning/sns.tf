resource "aws_sns_topic" "config" {
  name              = "${local.prefix}-config"
  display_name      = "AWS Config notification topic for ${var.project} ${var.environment}"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_policy" "config" {
  arn = aws_sns_topic.config.arn
  policy = templatefile("${path.module}/templates/sns-policy.json.tftpl",
  { topic : aws_sns_topic.config.arn })
}

resource "aws_sns_topic_subscription" "config" {
  topic_arn = aws_sns_topic.config.arn
  endpoint  = var.notification_email
  protocol  = "email"
}
