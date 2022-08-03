terraform {
  backend "s3" {
    bucket = "r911-non-prod-terraform"
    key    = "non-prod/terraform.tfstate"
    region = "us-east-1"
  }
}

module "backend" {
  source = "../../modules/backend"

  project             = "r911"
  region              = "us-east-1"
  environment         = "non-prod"
  key_recovery_period = 7
}

module "security-scanning" {
  source = "../../modules/security-scanning"

  project            = "r911"
  region             = "us-east-1"
  environment        = "non-prod"
  notification_email = "jarmes@codeforamerica.org"
}
