# ─── Resource Group ──────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the deployed resource group."
  value       = module.resource_group.id
}

# ─── Network ─────────────────────────────────────────────────────────────────

output "vnet_name" {
  description = "Name of the virtual network."
  value       = module.network.vnet_name
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = module.network.vnet_id
}

output "management_subnet_id" {
  description = "Resource ID of the management subnet."
  value       = module.network.management_subnet_id
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet."
  value       = module.network.workload_subnet_id
}

# ─── Compute ─────────────────────────────────────────────────────────────────

output "vm_name" {
  description = "Name of the workload virtual machine."
  value       = module.compute.vm_name
}

output "vm_private_ip" {
  description = "Private IP address of the workload VM."
  value       = module.compute.private_ip
}

output "vm_principal_id" {
  description = "Principal (Object) ID of the VM's system-assigned managed identity."
  value       = module.compute.principal_id
}

# ─── Bastion ─────────────────────────────────────────────────────────────────

output "bastion_name" {
  description = "Name of the Azure Bastion host."
  value       = module.bastion.bastion_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Azure Bastion host."
  value       = module.bastion.bastion_public_ip
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = module.monitoring.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = module.monitoring.workspace_name
}

output "sentinel_workspace_id" {
  description = "Log Analytics workspace ID where Microsoft Sentinel is enabled."
  value       = module.monitoring.workspace_id
}

output "soc_dashboard_workbook_id" {
  description = "Resource ID of the SOC detection dashboard workbook."
  value       = module.monitoring.workbook_id
}
