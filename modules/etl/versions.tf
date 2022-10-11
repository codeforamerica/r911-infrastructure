terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      version = ">= 4.22"
      source  = "hashicorp/aws"
    }

    template = {
      version = ">= 2.2"
      source  = "hashicorp/template"
    }
  }
}
