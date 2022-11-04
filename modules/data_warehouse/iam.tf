resource "aws_iam_role" "warehouse_s3" {
  name = "${local.prefix}-warehouse-s3"

  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [aws_iam_policy.warehouse_s3_read.arn]
}

resource "aws_iam_policy" "warehouse_s3_read" {
  name = "${local.prefix}-warehouse-s3-read"

  policy = templatefile("${path.module}/templates/warehouse-s3-read-policy.json.tftpl", {
#    log_group : aws_cloudwatch_log_group.logs["/aws/cloudtrail"].arn,
  })
}
