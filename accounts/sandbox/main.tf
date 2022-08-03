terraform {
  backend "s3" {
    bucket = "solutions-eng-sandbox-terraform"
    key    = "non-prod/terraform.tfstate"
    region = "us-east-1"
  }
}

module "backend" {
  source = "../../modules/backend"

  project             = "solutions-eng"
  region              = "us-east-1"
  environment         = "sandbox"
  key_recovery_period = 7
}

module "security-scanning" {
  source = "../../modules/security-scanning"

  project            = "solutions-eng"
  region             = "us-east-1"
  environment        = "sandbox"
  notification_email = "jarmes@codeforamerica.org"
}
