terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      version = ">= 4.22"
      source  = "hashicorp/aws"
    }

    dns = {
      version = ">= 3.2"
      source  = "hashicorp/dns"
    }

    random = {
      version = ">= 3.3"
      source  = "hashicorp/random"
    }
  }
}
