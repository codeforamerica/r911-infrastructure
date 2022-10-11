variable "data_lake_bucket" {
  type        = string
  description = "Name of the bucket for the data lake."
}

variable "encryption_key" {
  type        = string
  description = "ARN of the KMS key to use for encryption."
}

variable "environment" {
  type        = string
  default     = "development"
  description = "Environment for this deployment. If this is different than the Rails environment, pleas set rails_environment."
}

variable "key_recovery_period" {
  type        = number
  default     = 30
  description = "Recovery period for deleted KMS keys in days. Must be between 7 and 30."

  validation {
    condition     = var.key_recovery_period > 6 && var.key_recovery_period < 31
    error_message = "Recovery period must be between 7 and 30."
  }
}

variable "logging_bucket" {
  type        = string
  description = "Name of the bucket to use for logs."
}

variable "project" {
  type        = string
  default     = "r911"
  description = "Project that these resources are supporting."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy resources into."
}

variable "warehouse_endpoint" {
  #  type = object
  type = object({
    address = string,
    port    = number,
    vpc_endpoint = list(object({
      network_interface = list(object({
        availability_zone = string
        subnet_id         = string
      }))
    }))
  })

  description = "sdtuff"
}

variable "warehouse_credentials_secret" {
  type        = string
  description = "Name of the SecretsManager secret for data warehouse credentials."
}
