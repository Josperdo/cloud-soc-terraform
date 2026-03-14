variable "vm_name" {
  description = "Name of the virtual machine."
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

variable "subnet_id" {
  description = "Resource ID of the subnet to attach the VM's NIC to."
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU (e.g. Standard_B2s)."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local administrator username on the VM."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH RSA public key for VM authentication."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all compute resources."
  type        = map(string)
  default     = {}
}
