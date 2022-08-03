terraform {
  required_providers {
    aws = {
      version = ">= 4.22.0"
      source  = "hashicorp/aws"
    }

    null = {
      version = ">= 3.1"
      source  = "hashicorp/null"
    }
  }
}
