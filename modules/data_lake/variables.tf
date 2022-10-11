variable "admin_user_group" {
  type        = string
  default     = "Administrators"
  description = "Name of the IAM user group for administrators."
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

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region to manage resources in."
}
