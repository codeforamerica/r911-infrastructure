provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project     = "r911"
      environment = var.environment
    }
  }
}
