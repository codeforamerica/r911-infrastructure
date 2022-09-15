# TODO:
# * S3 for file uploads
# * Blue/Green deployments
# * Rollbacks
# * Monitoring & Alerting
# * Lambda to clean up empty log streams
# * Backups

terraform {
  backend "s3" {
    bucket = "r911-non-prod-terraform"
    key    = "development/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  project     = "r911"
  region      = "us-east-1"
  environment = "development"
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
  log_retention            = 1
  vpc_id                   = module.networking.vpc_id
  url_domain               = "nprd.classifyr.org"
  untagged_image_retention = 1
  key_recovery_period      = 7
  secret_recovery_period   = 0
  skip_db_final_snapshot   = true
  enable_execute_command   = true
  passive_waf              = false
  desired_containers       = 3
  idle_timeout             = 300
  deployment_rollback      = false

  environment_variables = {
    LAUNCHY_DRY_RUN : true,
    BROWSER : "/dev/null",
    RAILS_EMAIL_DOMAIN : "development.nprd.classifyr.org",
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
  web_security_group_id = module.hosting.web_security_group.id
}
