output "vm_id" {
  description = "Resource ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address assigned to the VM's NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "principal_id" {
  description = "Principal (Object) ID of the VM's system-assigned managed identity."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

output "nic_id" {
  description = "Resource ID of the VM's network interface."
  value       = azurerm_network_interface.this.id
}
