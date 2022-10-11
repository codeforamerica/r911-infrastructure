output "cluster" {
  value = aws_redshiftserverless_workgroup.warehouse
}

output "crednetials_secret" {
  value = aws_secretsmanager_secret.admin
}
