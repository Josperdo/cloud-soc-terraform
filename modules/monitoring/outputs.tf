output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_customer_id" {
  description = "Workspace (Customer) ID used for agent configuration."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "dcr_id" {
  description = "Resource ID of the Linux syslog Data Collection Rule."
  value       = azurerm_monitor_data_collection_rule.linux_syslog.id
}

output "workbook_id" {
  description = "Resource ID of the SOC detection dashboard workbook."
  value       = azurerm_application_insights_workbook.soc_dashboard.id
}
