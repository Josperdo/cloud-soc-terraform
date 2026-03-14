variable "prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into."
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block(s) for the Virtual Network."
  type        = list(string)
}

variable "management_subnet_cidr" {
  description = "CIDR for the management subnet."
  type        = string
}

variable "workload_subnet_cidr" {
  description = "CIDR for the workload subnet."
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "CIDR for the AzureBastionSubnet. Must be /26 or larger."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all network resources."
  type        = map(string)
  default     = {}
}
