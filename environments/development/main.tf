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

module "networking" {
  source = "../../modules/networking"

  project            = "r911"
  region             = "us-east-1"
  environment        = "development"
  single_nat_gateway = true
}

module "hosting" {
  source = "../../modules/rails_hosting"

  force_delete = true

  project                  = "r911"
  region                   = "us-east-1"
  environment              = "development"
  log_retention            = 1
  vpc_id                   = module.networking.vpc_id
  url_domain               = "nprd.classifyr.org"
  untagged_image_retention = 1
  key_recovery_period      = 7
  secret_recovery_period   = 0
  skip_db_final_snapshot   = true
  enable_execute_command   = true

  environment_variables = {
    LAUNCHY_DRY_RUN : true,
    BROWSER : "/dev/null",
  }
}

module "ci_cd" {
  source = "../../modules/ci_cd"

  project               = "r911"
  region                = "us-east-1"
  environment           = "development"
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
}
