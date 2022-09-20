variable "database_backup_retention" {
  type        = number
  default     = 7
  description = "The number of days database backups should be retained."
}

variable "database_instances" {
  type        = number
  default     = 2
  description = "Number of Aurora instances to be launched in the database cluster."
}

variable "database_starting_snapshot" {
  type        = string
  default     = ""
  description = "Optional snapshot to launch the database cluster from."
}

variable "database_username" {
  type        = string
  default     = "postgres"
  description = "Username for the master database user."
}

variable "deployment_rollback" {
  type        = bool
  default     = false
  description = "Whether or not to perform a rollback when a Fargate deployment fails."
}

variable "desired_containers" {
  type        = string
  default     = 3
  description = "Desired number of containers to server the application."
}

variable "enable_execute_command" {
  type        = bool
  default     = false
  description = "Enable command execution in service containers. Useful for debugging in non-production environments. Does not apply to currently running tasks."
}

variable "environment" {
  type        = string
  default     = "development"
  description = "Environment for this deployment. If this is different than the Rails environment, pleas set rails_environment."
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Additional environment variables to set on the web containers."
}

variable "force_delete" {
  type        = bool
  default     = false
  description = "Forcefully delete resources. USE WITH CAUTION!"
}

variable "idle_timeout" {
  type        = number
  default     = 60
  description = "Timeout for idle connections."
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag to use for the container image."
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

variable "log_retention" {
  type        = number
  default     = 7
  description = "Number of days logs are retained (0 for indefinite)."
}

variable "passive_waf" {
  type        = bool
  default     = false
  description = <<-EOT
Set all WAF rules to count only. This can be useful when validating that valid
traffic is not blocked. WARNING: THIS PROVIDES NO SECURITY!
EOT
}

variable "rails_environment" {
  type        = string
  default     = ""
  description = "Rails environment. Defaults to the same value as \"environment\" if not set."
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

variable "skip_db_final_snapshot" {
  type        = bool
  default     = false
  description = "Skip the final snapshot when destroying the database cluster. USE WITH CAUTION!"
}

variable "subdomain" {
  type        = string
  default     = ""
  description = "Subdomain for the hosted application. Defaults to the environment name."
}

variable "untagged_image_retention" {
  type        = number
  default     = 14
  description = "Retention period (after push) for untagged images"
}

variable "url_domain" {
  type        = string
  description = "Domain for URL creation. Should match a hosted zone in the deployment account."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy resources into."
}
