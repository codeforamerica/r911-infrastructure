locals {
  warehouse_interface = var.warehouse_endpoint.vpc_endpoint[0].network_interface[0]
}

resource "aws_glue_catalog_database" "database" {
  name        = local.prefix
  description = "Data catalog for ${var.project} ${var.environment}."
}

resource "aws_glue_catalog_table" "input" {
  name          = "${var.project}_input"
  database_name = aws_glue_catalog_database.database.name

  lifecycle {
    #    ignore_changes = [name]
    ignore_changes = [name, owner, parameters, table_type, storage_descriptor]
  }
}

resource "aws_glue_connection" "vpc" {
  name            = "${local.prefix}-vpc-${local.warehouse_interface.availability_zone}"
  description     = "VPC connection for ${var.project} ${var.environment}."
  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = local.warehouse_interface.availability_zone
    subnet_id              = local.warehouse_interface.subnet_id
    security_group_id_list = [data.aws_security_group.default.id]
  }
}

resource "aws_glue_connection" "warehouse" {
  name            = "${local.prefix}-warehouse-${local.warehouse_interface.availability_zone}"
  description     = "Data warehouse connection for ${var.project} ${var.environment}."
  connection_type = "JDBC"

  connection_properties = {
    # TODO: Update to use the secret directly once we can track down why it's
    # not working.
    USERNAME = local.warehouse_creds["username"]
    PASSWORD = local.warehouse_creds["password"]
    JDBC_CONNECTION_URL = join("", [
      "jdbc:redshift://",
      var.warehouse_endpoint.address,
      ":",
      var.warehouse_endpoint.port,
      "/dev?ssl=true&sslfactory=org.postgresql.ssl.NonValidatingFactory"
    ])
  }

  physical_connection_requirements {
    availability_zone      = local.warehouse_interface.availability_zone
    subnet_id              = local.warehouse_interface.subnet_id
    security_group_id_list = [data.aws_security_group.default.id]
  }

  lifecycle {
    ignore_changes = [name]
  }
}

locals {
  jobs = {
    arizona-phoenix : {
      name : "arizona-phoenix",
      script : "scripts/arizona-phoenix.py",
      workers : 2,
    },
    louisiana-new-orleans : {
      name : "louisiana-new-orleans",
      script : "scripts/louisiana-new-orleans.py",
      workers : 2,
    },
    maryland-baltimore : {
      name : "maryland-baltimore",
      script : "scripts/maryland-baltimore.py",
      workers : 2,
    },
    massachusetts-worcester : {
      name : "massachusetts-worcester",
      script : "scripts/massachusetts-worcester.py",
      workers : 2,
    },
    vermont-burlington : {
      name : "vermont-burlington",
      script : "scripts/vermont-burlington.py",
      workers : 2,
    },
  }
}

resource "aws_s3_object" "scripts" {
  for_each = local.jobs

  bucket      = aws_s3_bucket.etl.bucket
  key         = each.value.script
  source      = "${path.module}/${each.value.script}"
  source_hash = filemd5("${path.module}/${each.value.script}")
}

resource "aws_glue_job" "baltimore" {
  for_each = local.jobs

  name     = "${local.prefix}-${each.value.name}"
  role_arn = aws_iam_role.job.arn

  connections = [
    aws_glue_connection.vpc.name,
    aws_glue_connection.warehouse.name,
  ]

  number_of_workers = each.value.workers
  worker_type       = "G.1X"
  glue_version      = "3.0"

  command {
    script_location = "s3://${aws_s3_object.scripts[each.key].bucket}/${each.value.script}"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir" : "s3://${aws_s3_bucket.etl.bucket}/temporary",
    "--class" : "GlueApp",
    "--enable-continuous-cloudwatch-log" : true,
    "--enable-glue-datacatalog" : true,
    "--enable-job-insights" : true,
    "--enable-metrics" : true,
    "--enable-spark-ui" : true,
    "--job-bookmark-option" : "job-bookmark-disable",
    "--job-language" : "python",
    "--spark-event-logs-path" : "s3://${aws_s3_bucket.etl.bucket}/sparkHistoryLogs/",
    "--ENVIRONMENT" : var.environment,
    "--REDSHIFT_CONNECTION" : aws_glue_connection.warehouse.name,
    "--DATA_LAKE_URL" : "s3://${var.data_lake_bucket}/data/",
  }
}
