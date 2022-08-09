output "connection_url" {
  value = "https://${var.region}.console.aws.amazon.com/codesuite/settings/${data.aws_caller_identity.identity.account_id}/${var.region}/connections/${local.connection_id}"
}

output "arns" {
  value = [for group in aws_cloudwatch_log_group.logs : group.arn]
}
