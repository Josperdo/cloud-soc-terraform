# ─── Identity ───────────────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure Subscription ID. Can also be set via the ARM_SUBSCRIPTION_ID environment variable."
  type        = string
}

# ─── Naming & Placement ──────────────────────────────────────────────────────

variable "prefix" {
  description = "Short prefix prepended to every resource name (keep it lowercase, 2-6 chars)."
  type        = string
  default     = "soc"

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.prefix))
    error_message = "prefix must be 2-6 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region for all resources (e.g. 'East US', 'West Europe')."
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment tag applied to all resources (e.g. lab, dev, prod)."
  type        = string
  default     = "lab"
}

variable "tags" {
  description = "Additional tags merged onto every resource. Built-in tags (environment, project, managed_by) are always applied."
  type        = map(string)
  default     = {}
}

# ─── Network ─────────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "CIDR block(s) for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "management_subnet_cidr" {
  description = "CIDR for the management subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "workload_subnet_cidr" {
  description = "CIDR for the workload subnet (hosts VMs)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_subnet_cidr" {
  description = "CIDR for the AzureBastionSubnet. Azure requires a minimum /26."
  type        = string
  default     = "10.0.3.0/26"
}

# ─── Compute ─────────────────────────────────────────────────────────────────

variable "vm_size" {
  description = "Azure VM SKU for the workload virtual machine."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local admin username on the workload VM."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH RSA public key used to authenticate to the workload VM."
  type        = string
  sensitive   = true
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "Log Analytics workspace data retention in days (30-730)."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}
