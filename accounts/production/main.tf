terraform {
  backend "s3" {
    bucket = "r911-production-terraform"
    key    = "non-prod/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  project     = "r911"
  region      = "us-east-1"
  environment = "production"
}

module "backend" {
  source = "../../modules/backend"

  project             = local.project
  region              = local.region
  environment         = local.environment
  key_recovery_period = 7
}

module "security-scanning" {
  source = "../../modules/security-scanning"

  project            = local.project
  region             = local.region
  environment        = local.environment
  notification_email = "reimagine911+security@codeforamerica.org"
}
