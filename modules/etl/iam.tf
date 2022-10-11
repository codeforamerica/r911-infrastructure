resource "aws_iam_role" "job" {
  name = "${local.prefix}-etl-job"

  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "DataAccess"
    policy = templatefile("${path.module}/templates/iam-policy.json.tftpl", {
      etl_bucket : aws_s3_bucket.etl.arn,
      data_lake_bucket : data.aws_s3_bucket.data_lake.arn,
      encryption_key : var.encryption_key,
    })
  }

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSGlueServiceRole",
  ]

  lifecycle {
    create_before_destroy = true
  }
}
