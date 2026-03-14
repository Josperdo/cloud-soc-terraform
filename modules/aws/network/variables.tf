variable "prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "management_subnet_cidr" {
  description = "CIDR for the management subnet (public, SSM access)."
  type        = string
}

variable "workload_subnet_cidr" {
  description = "CIDR for the workload subnet (private, isolated)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all network resources."
  type        = map(string)
  default     = {}
}
