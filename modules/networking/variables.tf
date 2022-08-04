variable "availability_zones" {
  type        = number
  default     = 3
  description = "Number of availability zones to create subnets for."

  # TODO: Support a number of availability zones greater than 1 other than 3.
  validation {
    #    condition = var.availability_zones > 1
    #    error_message = "You must deploy to at least 2 availability zones."
    condition     = var.availability_zones == 3
    error_message = "Currently only 3 availability zones are supported."
  }
}

variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "IPv4 CIDR block for the VPC."
}

variable "environment" {
  type        = string
  default     = "development"
  description = "Environment for this deployment. If this is different than the Rails environment, pleas set rails_environment."
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

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "Enable to deploy one NAT gateway rather than one per subnet. Cheaper, but is not highly available."
}
