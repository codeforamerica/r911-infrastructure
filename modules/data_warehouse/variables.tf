variable "base_rpu" {
  type = number
  default = 32
  description = "The base Redshift processing units (RSU) to assign to the Redshift cluster."
}

variable "data_lake_bucket" {
  type        = string
  description = "Name of the bucket to be used as a data lake."
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

variable "logging_bucket" {
  type        = string
  description = "Name of the bucket to use for logs."
}

variable "project" {
  type        = string
  default     = "r911"
  description = "Project that these resources are supporting."
}

variable "secret_recovery_period" {
  type        = number
  default     = 0
  description = "Recovery period for deleted secrets. Must be 0 (disabled) or between 7 and 30."

  validation {
    condition = var.secret_recovery_period == 0 || (
      var.secret_recovery_period > 6 && var.secret_recovery_period < 31
    )
    error_message = "Recovery period must be 0 or between 7 and 30."
  }
}

variable "url_domain" {
  type        = string
  description = "Domain for URL creation. Should match a hosted zone in the deployment account."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy resources into."
}
