# TODO: Add password rotation once the secret is working with AWS Glue.
resource "aws_secretsmanager_secret" "admin" {
  name_prefix             = "/${var.project}/${var.environment}/warehouse/admin-"
  description             = "Admin Redshift credentials."
  recovery_window_in_days = var.secret_recovery_period
  kms_key_id              = var.encryption_key

  lifecycle {
    # The secret rotation lambda will fail if the host name of a cluster is
    # changed, so we need to create a new secret when that happens.
    replace_triggered_by  = [aws_redshiftserverless_workgroup.warehouse.endpoint[0].address]
    create_before_destroy = true
    ignore_changes        = [name, name_prefix]
  }
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({
    username : aws_redshiftserverless_namespace.warehouse.admin_username
    password : aws_redshiftserverless_namespace.warehouse.admin_user_password
    engine : "redshift"
    host : aws_redshiftserverless_workgroup.warehouse.endpoint[0].address
    port : aws_redshiftserverless_workgroup.warehouse.endpoint[0].port
    dbClusterIdentifier : aws_redshiftserverless_namespace.warehouse.namespace_name
  })

  lifecycle {
    # We're only using this to set the initial value, so ignore future changes.
    ignore_changes = [secret_string]
  }
}
