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

variable "bastion_subnet_id" {
  description = "Resource ID of the AzureBastionSubnet."
  type        = string
}

variable "bastion_sku" {
  description = "SKU of the Azure Bastion host. 'Basic' is lowest cost; 'Standard' adds features like native client support and file copy."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.bastion_sku)
    error_message = "bastion_sku must be one of: Basic, Standard, Premium."
  }
}

variable "tags" {
  description = "Tags to apply to all bastion resources."
  type        = map(string)
  default     = {}
}
