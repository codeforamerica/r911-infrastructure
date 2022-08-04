resource "aws_db_subnet_group" "db" {
  name       = "${local.prefix}-db-subnets"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_rds_cluster" "db" {
  cluster_identifier     = local.prefix
  db_subnet_group_name   = aws_db_subnet_group.db.name
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "14.3"
  vpc_security_group_ids = [aws_security_group.db_access.id]
  skip_final_snapshot    = var.skip_db_final_snapshot
  copy_tags_to_snapshot  = true

  master_password = data.aws_secretsmanager_random_password.db_master.random_password
  master_username = var.database_username

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 16
  }

  lifecycle {
    ignore_changes = [master_password]
  }

  depends_on = [aws_cloudwatch_log_group.logs]
}

resource "aws_rds_cluster_instance" "db" {
  count               = var.database_instances
  identifier          = "${local.prefix}-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.db.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.db.engine
  engine_version      = aws_rds_cluster.db.engine_version
  monitoring_interval = 60
  promotion_tier      = 1
  monitoring_role_arn = aws_iam_role.db_monitoring.arn

  lifecycle {
    ignore_changes = [identifier]
  }
}
