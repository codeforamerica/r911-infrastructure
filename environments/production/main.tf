terraform {
  backend "s3" {
    bucket = "r911-production-terraform"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  project     = "r911"
  region      = "us-east-1"
  environment = "production"
}

module "networking" {
  source = "../../modules/networking"

  project            = local.project
  region             = local.region
  environment        = local.environment
  single_nat_gateway = true
}

module "hosting" {
  source     = "../../modules/rails_hosting"
  depends_on = [module.networking.vpc_id]

  project                  = local.project
  region                   = local.region
  environment              = local.environment
  subdomain                = "www"
  log_retention            = 1
  deployment_rollback      = true
  vpc_id                   = module.networking.vpc_id
  url_domain               = "classifyr.org"
  untagged_image_retention = 1
  key_recovery_period      = 7
  secret_recovery_period   = 0
  skip_db_final_snapshot   = false
  enable_execute_command   = true
  containers_max_capacity  = 3
  containers_min_capacity  = 1
  idle_timeout             = 300
  database_instances       = 1
  database_max_capacity    = 3
  database_min_capacity    = 2

  # Snapshot created in order to enable encryption at rest.
  database_starting_snapshot = "r911-production-encrypt"

  environment_variables = {
    LAUNCHY_DRY_RUN : true,
    BROWSER : "/dev/null",
    RAILS_EMAIL_DOMAIN : "classifyr.org",
  }
}

module "ci_cd" {
  source     = "../../modules/ci_cd"
  depends_on = [module.hosting.web_cluster_name]

  project               = local.project
  region                = local.region
  environment           = local.environment
  repository            = "codeforamerica/classifyr"
  branch                = "main"
  cluster_name          = module.hosting.web_cluster_name
  service_name          = module.hosting.web_service_name
  task_execution_role   = module.hosting.task_task_definition.execution_role_arn
  task_task_definition  = module.hosting.task_task_definition.id
  vpc_id                = module.networking.vpc_id
  log_retention         = 1
  key_recovery_period   = 7
  image_repository_name = module.hosting.image_repository.name
  logging_bucket        = module.hosting.logging_bucket.id
  web_security_group_id = module.hosting.web_security_group.id
}

module "data_lake" {
  source = "../../modules/data_lake"

  project          = local.project
  region           = local.region
  environment      = local.environment
  logging_bucket   = module.hosting.logging_bucket.id
  admin_user_group = "Admin"
}

module "data_warehouse" {
  source = "../../modules/data_warehouse"

  project          = local.project
  environment      = local.environment
  vpc_id           = module.networking.vpc_id
  encryption_key   = module.data_lake.encryption_key.arn
  logging_bucket   = module.hosting.logging_bucket.id
  url_domain       = "classifyr.org"
  data_lake_bucket = module.data_lake.bucket.bucket
}

module "etl" {
  source = "../../modules/etl"

  project        = local.project
  environment    = local.environment
  vpc_id         = module.networking.vpc_id
  logging_bucket = module.hosting.logging_bucket.id

  warehouse_endpoint           = module.data_warehouse.cluster.endpoint[0]
  warehouse_credentials_secret = module.data_warehouse.crednetials_secret.name
  data_lake_bucket             = module.data_lake.bucket.bucket
  encryption_key               = module.data_lake.encryption_key.arn
}
