resource "aws_iam_account_password_policy" "policy" {
  allow_users_to_change_password = true
  max_password_age               = 90
  minimum_password_length        = 14
  password_reuse_prevention      = 24
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  require_uppercase_characters   = true
}

resource "aws_iam_role" "config" {
  name = "${local.prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "cloudtrail" {
  name        = "${local.prefix}-cloudtrail"
  description = "Role used by CloudTrail to write CloudWatch logs."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })


}

resource "aws_iam_policy" "cloudtrail_to_cloudwatch" {
  name = "${local.prefix}-cloudtrail_to_cloudwatch"

  policy = templatefile("${path.module}/templates/cloudtrail-to-cloudwatch-policy.json.tftpl", {
    log_group : aws_cloudwatch_log_group.logs["/aws/cloudtrail"].arn,
  })
}
