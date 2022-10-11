locals {
  prefix        = "${var.project}-${var.environment}"
  aws_logs_path = "/AWSLogs/${data.aws_caller_identity.identity.account_id}"
}

data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_iam_group" "admins" {
  group_name = var.admin_user_group
}

resource "aws_lakeformation_data_lake_settings" "lake" {
  admins = [for user in data.aws_iam_group.admins.users : user.arn]
}

resource "aws_lakeformation_resource" "data" {
  arn = "${aws_s3_bucket.lake.arn}/data"
}

resource "aws_lakeformation_resource" "input" {
  arn = "${aws_s3_bucket.lake.arn}/input"
}
