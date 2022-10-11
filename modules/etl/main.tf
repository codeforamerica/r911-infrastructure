locals {
  prefix          = "${var.project}-${var.environment}"
  aws_logs_path   = "/AWSLogs/${data.aws_caller_identity.identity.account_id}"
  warehouse_creds = jsondecode(data.aws_secretsmanager_secret_version.warehouse.secret_string)
}

data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_security_group" "default" {
  vpc_id = var.vpc_id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}

data "aws_s3_bucket" "data_lake" {
  bucket = var.data_lake_bucket
}

data "aws_secretsmanager_secret_version" "warehouse" {
  secret_id = var.warehouse_credentials_secret
}
