# ─── Sentinel SOC Detection Dashboard Workbook ───────────────────────────────
#
# An Azure Monitor Workbook (category: sentinel) with three query tiles that
# surface the detection categories covered by the analytics rules in this lab:
#
#   1. Failed SSH Logins      — feeds Rule 1 (SSH Brute Force)
#   2. Privilege & Account    — feeds Rules 2, 4, 5, 6, 8
#   3. Persistence Events     — feeds Rules 3, 9
#
# The workbook is visible in:
#   Sentinel → Threat Management → Workbooks → My Workbooks
#
# Each KQL tile queries the same Log Analytics workspace used by Sentinel,
# scoped to the last 24 hours by default. Time range can be changed in the
# Azure Portal once the workbook is open.

locals {
  workbook_data = jsonencode({
    version = "Notebook/1.0"
    items = [
      # ── Header ─────────────────────────────────────────────────────────────
      {
        type = 1
        content = {
          json = join("\n", [
            "# SOC Detection Dashboard",
            "",
            "This workbook surfaces activity for the three detection categories",
            "deployed in this lab. All queries target the `Syslog` table fed by",
            "the Azure Monitor Agent (AMA) running on the workload VM.",
            "",
            "> **Tip:** Use the time picker at the top-right to adjust the lookback window.",
          ])
        }
        name = "header"
      },

      # ── Section 1: Failed SSH Logins ────────────────────────────────────────
      {
        type = 1
        content = {
          json = "## Failed SSH Logins (Last 24 Hours)\n\nBrute force detection per-IP, binned by hour. A burst from a single IP maps to **Rule 1 — SSH Brute Force (T1110.001)**."
        }
        name = "section-ssh"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = join("\n", [
            "Syslog",
            "| where Facility in (\"auth\", \"authpriv\")",
            "| where SyslogMessage has \"Failed password\"",
            "| where TimeGenerated >= ago(24h)",
            "| summarize Attempts = count() by HostIP, bin(TimeGenerated, 1h)",
            "| order by TimeGenerated desc",
          ])
          size                    = 0
          timeContext             = { durationMs = 86400000 }
          queryType               = 0
          resourceType            = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [azurerm_log_analytics_workspace.this.id]
          visualization           = "table"
          gridSettings = {
            formatters = [
              { columnMatch = "Attempts", formatter = 8, formatOptions = { palette = "redGreen" } }
            ]
          }
        }
        name = "query-ssh-logins"
      },

      # ── Section 2: Privilege & Account Events ──────────────────────────────
      {
        type = 1
        content = {
          json = "## Privilege & Account Events (Last 24 Hours)\n\nCovers sudo group changes (**T1548.003**), new accounts (**T1136.001**), root SSH logins (**T1078**), failed sudo (**T1548.003**), and password changes (**T1098**)."
        }
        name = "section-privilege"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = join("\n", [
            "Syslog",
            "| where TimeGenerated >= ago(24h)",
            "| where Facility in (\"auth\", \"authpriv\")",
            "| where SyslogMessage has_any (",
            "    \"to group sudo\", \"to group wheel\", \"added to group\",",
            "    \"new user:\", \"useradd[\", \"adduser[\",",
            "    \"password changed for\",",
            "    \"sudo\", \"authentication failure\"",
            "  )",
            "  or (SyslogMessage has \"Accepted\" and SyslogMessage has \"root\")",
            "| project TimeGenerated, Computer, HostIP, SyslogMessage",
            "| order by TimeGenerated desc",
          ])
          size                    = 0
          timeContext             = { durationMs = 86400000 }
          queryType               = 0
          resourceType            = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [azurerm_log_analytics_workspace.this.id]
          visualization           = "table"
        }
        name = "query-privilege-events"
      },

      # ── Section 3: Persistence Events ──────────────────────────────────────
      {
        type = 1
        content = {
          json = "## Persistence Events (Last 24 Hours)\n\nCovers cron job creation (**T1053.003**) and new systemd service installation (**T1543.002**)."
        }
        name = "section-persistence"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query = join("\n", [
            "Syslog",
            "| where TimeGenerated >= ago(24h)",
            "| where",
            "    (Facility == \"cron\"",
            "     and SyslogMessage has_any (\"REPLACE\", \"new job\", \"BEGIN EDIT\")",
            "     and SyslogMessage !has \"root\")",
            "  or",
            "    (Facility == \"daemon\"",
            "     and ProcessName == \"systemd\"",
            "     and SyslogMessage has \"Created symlink\"",
            "     and SyslogMessage has \".service\")",
            "| project TimeGenerated, Computer, HostIP, Facility, SyslogMessage",
            "| order by TimeGenerated desc",
          ])
          size                    = 0
          timeContext             = { durationMs = 86400000 }
          queryType               = 0
          resourceType            = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [azurerm_log_analytics_workspace.this.id]
          visualization           = "table"
        }
        name = "query-persistence-events"
      },
    ]
  })
}

resource "azurerm_application_insights_workbook" "soc_dashboard" {
  # Name must be a GUID — derived deterministically from the prefix so it is
  # stable across plan/apply cycles and unique per deployment prefix.
  name                = uuidv5("url", "soc-dashboard-${var.prefix}")
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "${var.prefix}-soc-dashboard"
  category            = "sentinel"
  data_json           = local.workbook_data
  tags                = var.tags

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}
