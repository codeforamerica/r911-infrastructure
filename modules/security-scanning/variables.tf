variable "config_delivery_frequency" {
  type        = string
  default     = "One_Hour"
  description = "How often AWS Config delivers configuration snapshots. "

  validation {
    condition = contains(
      ["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"],
      var.config_delivery_frequency
    )
    error_message = "Invalid value. See https://docs.aws.amazon.com/config/latest/APIReference/API_ConfigSnapshotDeliveryProperties.html#API_ConfigSnapshotDeliveryProperties_Contents"
  }
}

variable "environment" {
  type        = string
  default     = "non-prod"
  description = "Environment for the deployment."
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

variable "notification_email" {
  type        = string
  default     = ""
  description = "Email that all notifications should be sent to."
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
