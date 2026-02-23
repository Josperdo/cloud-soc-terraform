# ─── Sentinel Scheduled Analytics Rules ──────────────────────────────────────
#
# All three rules target the Syslog table populated by the AMA/DCR pipeline.
# KQL queries are drafted here and should be validated in Log Analytics before
# deploying to a live workspace. Sentinel must be onboarded before rules can
# be created — all resources depend on the onboarding resource.
#
# MITRE coverage:
#   T1110.001  Brute Force: Password Guessing (SSH)
#   T1548.003  Abuse Elevation Control Mechanism: Sudo and Sudo Caching
#   T1053.003  Scheduled Task/Job: Cron

# ─── Rule 1: SSH Brute Force ─────────────────────────────────────────────────
# Detects ≥5 failed SSH authentication attempts from the same source IP
# within a 5-minute window. Maps to T1110.001 (Brute Force: Password Guessing).

resource "azurerm_sentinel_alert_rule_scheduled" "ssh_brute_force" {
  name                       = "${var.prefix}-rule-ssh-brute-force"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "SSH Brute Force Detected"
  description                = "Five or more failed SSH authentication attempts from the same source IP within 5 minutes. Indicates a brute force or credential stuffing attack."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility in ("auth", "authpriv")
    | where SyslogMessage has "Failed password"
    | summarize attempt_count = count() by HostIP, bin(TimeGenerated, 5m)
    | where attempt_count >= 5
    | project TimeGenerated, HostIP, attempt_count
  EOT

  query_frequency  = "PT5M"
  query_period     = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess"]
  techniques = ["T1110"]

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 2: Privilege Escalation via Sudo Group Add ─────────────────────────
# Detects a user being added to the sudo or wheel group, granting root-level
# access. Maps to T1548.003 (Abuse Elevation Control Mechanism: Sudo).

resource "azurerm_sentinel_alert_rule_scheduled" "sudo_group_add" {
  name                       = "${var.prefix}-rule-sudo-group-add"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "User Added to Sudo Group"
  description                = "A user was added to the sudo or wheel group, granting elevated privileges. Unexpected changes to privileged groups indicate a privilege escalation attempt."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "authpriv"
    | where SyslogMessage has_any ("to group sudo", "to group wheel", "added to group")
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency  = "PT5M"
  query_period     = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation"]
  techniques = ["T1548"]

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 3: Persistence via Cron Job ────────────────────────────────────────
# Detects a new cron entry created by a non-root user. Attackers use cron to
# maintain persistence by scheduling malicious scripts to run repeatedly.
# Maps to T1053.003 (Scheduled Task/Job: Cron).

resource "azurerm_sentinel_alert_rule_scheduled" "cron_persistence" {
  name                       = "${var.prefix}-rule-cron-persistence"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Cron Job Created by Non-Root User"
  description                = "A new cron job was written by a non-root user. Attackers schedule malicious scripts via cron to persist across reboots."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "cron"
    | where SyslogMessage has_any ("REPLACE", "new job", "BEGIN EDIT")
    | where SyslogMessage !has "root"
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency  = "PT5M"
  query_period     = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Persistence"]
  techniques = ["T1053"]

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}
