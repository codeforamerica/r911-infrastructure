resource "aws_serverlessapplicationrepository_cloudformation_stack" "db_master_rotation" {
  name           = "${local.prefix}-db-secret-rotation"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_RESOURCE_POLICY",
  ]

  parameters = {
    endpoint            = "https://secretsmanager.${var.region}.${data.aws_partition.current.dns_suffix}"
    excludeCharacters   = ":/@\"'\\"
    functionName        = "${local.prefix}-db-secret-rotation"
    vpcSecurityGroupIds = aws_security_group.db_access.id
    vpcSubnetIds        = join(",", data.aws_subnets.private.ids)
  }

  lifecycle {
    # Terraform always sees parameters.excludeCharacters as changed for some
    # reason.
    ignore_changes = [parameters]
  }

  depends_on = [aws_cloudwatch_log_group.logs]
}

resource "aws_secretsmanager_secret" "db_master" {
  name_prefix             = "/${var.project}/${var.environment}/database/master-"
  description             = "Master database credentials."
  recovery_window_in_days = var.secret_recovery_period
  kms_key_id              = aws_kms_key.hosting.arn

  lifecycle {
    # The secret rotation lambda will fail if the host name of a cluster is
    # changed, so we need to create a new secret when that happens.
    replace_triggered_by  = [aws_rds_cluster.db.endpoint]
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "db_secret" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username            = aws_rds_cluster.db.master_username
    password            = aws_rds_cluster.db.master_password
    engine              = "postgres"
    host                = aws_rds_cluster.db.endpoint
    port                = aws_rds_cluster.db.port
    dbClusterIdentifier = aws_rds_cluster.db.cluster_identifier
  })

  lifecycle {
    # We're only using this to set the initial value, so ignore future changes.
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "db_secret" {
  secret_id           = aws_secretsmanager_secret.db_master.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.db_master_rotation.outputs.RotationLambdaARN

  rotation_rules {
    automatically_after_days = 30
  }

  # We want to make sure we have a value set before enabling rotation.
  depends_on = [
    aws_secretsmanager_secret_version.db_secret
  ]
}

resource "aws_ssm_parameter" "web-keybase" {
  name   = "/${var.project}/${var.environment}/web/keybase"
  type   = "SecureString"
  value  = random_id.keybase.id
  key_id = aws_kms_key.hosting.arn
}
