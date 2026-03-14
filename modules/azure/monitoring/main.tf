# ─── Log Analytics Workspace ─────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

# ─── Microsoft Sentinel ───────────────────────────────────────────────────────
# Onboards Sentinel onto the Log Analytics workspace.
# Detection rules and analytics are Phase 2 work.

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = azurerm_log_analytics_workspace.this.id
}

# ─── Data Collection Rule (Linux Syslog) ─────────────────────────────────────
# Defines which syslog facilities and severity levels are collected from VMs
# running the Azure Monitor Agent and forwarded to the workspace.

resource "azurerm_monitor_data_collection_rule" "linux_syslog" {
  name                = "${var.prefix}-dcr-linux-syslog"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      name                  = "law-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-destination"]
  }

  data_sources {
    syslog {
      facility_names = [
        "auth",
        "authpriv",
        "cron",
        "daemon",
        "kern",
        "local6", # auditd events routed via audisp-syslog plugin
        "syslog",
        "user",
      ]
      log_levels = [
        "Debug",
        "Info",
        "Notice",
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency",
      ]
      name    = "syslog-datasource"
      streams = ["Microsoft-Syslog"]
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Azure Monitor Agent (AMA) VM Extension ──────────────────────────────────
# Installs the Azure Monitor Linux Agent on the workload VM.
# The agent uses the VM's system-assigned managed identity to authenticate —
# no stored credentials required.

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = var.vm_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# ─── Data Collection Rule Association ────────────────────────────────────────
# Links the DCR to the workload VM so the agent knows where to send data.

resource "azurerm_monitor_data_collection_rule_association" "vm_syslog" {
  name                    = "${var.prefix}-dcra-vm-syslog"
  target_resource_id      = var.vm_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux_syslog.id

  depends_on = [azurerm_virtual_machine_extension.ama]
}
