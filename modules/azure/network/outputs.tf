output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "management_subnet_id" {
  description = "Resource ID of the management subnet."
  value       = azurerm_subnet.management.id
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet."
  value       = azurerm_subnet.workload.id
}

output "bastion_subnet_id" {
  description = "Resource ID of the AzureBastionSubnet."
  value       = azurerm_subnet.bastion.id
}

output "management_nsg_id" {
  description = "Resource ID of the management subnet NSG."
  value       = azurerm_network_security_group.management.id
}

output "workload_nsg_id" {
  description = "Resource ID of the workload subnet NSG."
  value       = azurerm_network_security_group.workload.id
}
