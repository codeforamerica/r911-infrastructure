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
  passive_waf              = true
  desired_containers       = 3
  idle_timeout             = 300

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
  web_security_group_id = module.hosting.web_security_group.id
}
