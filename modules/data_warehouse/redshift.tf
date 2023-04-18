resource "aws_redshiftserverless_namespace" "warehouse" {
  namespace_name      = "${local.prefix}-warehouse"
  admin_user_password = data.aws_secretsmanager_random_password.admin.random_password
  admin_username      = "awsuser"

  lifecycle {
    ignore_changes = [admin_user_password, admin_username]
  }
}

resource "aws_redshiftserverless_workgroup" "warehouse" {
  namespace_name       = aws_redshiftserverless_namespace.warehouse.namespace_name
  workgroup_name       = "${local.prefix}-warehouse"
  base_capacity        = var.base_rpu
  enhanced_vpc_routing = true
  publicly_accessible  = false
  security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.warehouse_private.id,
  ]
  subnet_ids = data.aws_subnets.private.ids
}

# TODO: Replace with aws_redshiftdata_statement when it supports serverless.
resource "null_resource" "database" {
  depends_on = [aws_redshiftserverless_workgroup.warehouse]
  triggers = {
    project   = var.project
    workgroup = aws_redshiftserverless_workgroup.warehouse.workgroup_name
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
aws redshift-data execute-statement \
  --workgroup-name ${self.triggers.workgroup} \
  --database dev \
  --sql 'CREATE DATABASE ${self.triggers.project}'
EOT
  }
}
