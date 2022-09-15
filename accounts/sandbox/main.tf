terraform {
  backend "s3" {
    bucket = "solutions-eng-sandbox-terraform"
    key    = "non-prod/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  project     = "solutions-eng"
  region      = "us-east-1"
  environment = "sandbox"
}

module "backend" {
  source = "../../modules/backend"

  project             = local.project
  environment         = local.environment
  key_recovery_period = 7
}

module "security-scanning" {
  source = "../../modules/security-scanning"

  project            = local.project
  region             = local.region
  environment        = local.environment
  notification_email = "jarmes@codeforamerica.org"
}
