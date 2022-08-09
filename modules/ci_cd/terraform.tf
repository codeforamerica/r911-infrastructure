terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      version = ">= 4.22.0"
      source  = "hashicorp/aws"
    }
  }
}
