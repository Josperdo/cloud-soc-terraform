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

variable "vm_id" {
  description = "Resource ID of the workload VM to attach monitoring to."
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain data in the Log Analytics workspace (30-730)."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all monitoring resources."
  type        = map(string)
  default     = {}
}
