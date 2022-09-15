variable "branch" {
  type        = string
  default     = "main"
  description = "Name of the branch to build from."
}

variable "cluster_name" {
  type        = string
  description = "Name of the Fargate cluster that hosts the service."
}

variable "environment" {
  type        = string
  default     = "development"
  description = "Environment for this deployment. If this is different than the Rails environment, pleas set rails_environment."
}

variable "image_repository_name" {
  type        = string
  description = "Name of the ECR repository for the application container."
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

variable "repository" {
  type        = string
  description = "GitHub repository to generate builds from. Should be in the format org/repo-name."

  validation {
    condition     = can(regex("^[\\w-]+/[\\w-\\.]+$", var.repository))
    error_message = "Repository must be in the format org/repo-name."
  }
}

variable "service_name" {
  type        = string
  description = "Name of the Fargate service to deploy to."
}

variable "task_execution_role" {
  type        = string
  description = "ARN of the role to execute the migration task."
}

variable "task_task_definition" {
  type        = string
  description = "Id of the ECS task definition used to run tasks. This will be used for running database migrations."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy resources into."
}

variable "web_security_group_id" {
  type        = string
  description = "The security group for private resources in the web tier."
}
