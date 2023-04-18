resource "aws_db_subnet_group" "db" {
  name       = "${local.prefix}-db-subnets"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_rds_cluster" "db" {
  depends_on = [aws_cloudwatch_log_group.logs, aws_security_group.db_access]

  cluster_identifier_prefix = "${local.prefix}-"
  db_subnet_group_name      = aws_db_subnet_group.db.name
  engine                    = "aurora-postgresql"
  engine_mode               = "provisioned"
  vpc_security_group_ids    = [aws_security_group.db_access.id]
  skip_final_snapshot       = var.skip_db_final_snapshot
  final_snapshot_identifier = "${local.prefix}-final-snapshot"
  copy_tags_to_snapshot     = true
  snapshot_identifier       = var.database_starting_snapshot

  storage_encrypted       = true
  kms_key_id              = aws_kms_key.hosting.arn
  backup_retention_period = var.database_backup_retention

  master_password = data.aws_secretsmanager_random_password.db_master.random_password
  master_username = var.database_username

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.database_min_capacity
    max_capacity = var.database_max_capacity
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [master_password]
  }
}

resource "aws_rds_cluster_instance" "db" {
  count               = var.database_instances
  identifier_prefix   = "${local.prefix}-${count.index + 1}-"
  cluster_identifier  = aws_rds_cluster.db.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.db.engine
  engine_version      = aws_rds_cluster.db.engine_version
  monitoring_interval = 60
  promotion_tier      = 1
  monitoring_role_arn = aws_iam_role.db_monitoring.arn

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.hosting.arn

  lifecycle {
    create_before_destroy = true
  }
}
