# ─── Sentinel Scheduled Analytics Rules ──────────────────────────────────────
#
# All rules target the Syslog table populated by the AMA/DCR pipeline.
# The DCR collects from: auth, authpriv, cron, daemon, kern, syslog, user
# facilities at all severity levels.
#
# Entity mapping on each rule lets Sentinel automatically link Host and IP
# entities to incidents, enabling one-click pivot to entity timelines.
#
# KQL queries can be validated in Log Analytics → Logs before deploying.
# Sentinel must be onboarded before rules can be created — all resources
# depend on the onboarding resource.
#
# MITRE ATT&CK coverage (10 rules):
#   T1110.001  Brute Force: Password Guessing (SSH)          — Credential Access
#   T1548.003  Sudo and Sudo Caching (group add)             — Privilege Escalation
#   T1548.003  Sudo and Sudo Caching (failed attempts)       — Privilege Escalation
#   T1053.003  Scheduled Task/Job: Cron                      — Persistence
#   T1136.001  Create Account: Local Account                 — Persistence
#   T1078      Valid Accounts (root login)                   — Defense Evasion
#   T1070.002  Indicator Removal: Clear Linux Logs           — Defense Evasion
#   T1098      Account Manipulation (password change)        — Persistence
#   T1543.002  Create or Modify System Process: Systemd      — Persistence
#   T1059.004  Command and Scripting Interpreter: Unix Shell — Execution

# ─── Rule 1: SSH Brute Force ─────────────────────────────────────────────────
# Detects ≥5 failed SSH authentication attempts from the same source IP
# within a 5-minute window. Maps to T1110.001 (Brute Force: Password Guessing).
#
# Tuning: Reduce threshold for stricter detection (accept more false positives)
# or raise it for noisy environments. The 5-minute window catches fast bursts;
# consider PT15M period for slower, low-and-slow brute forces.

resource "azurerm_sentinel_alert_rule_scheduled" "ssh_brute_force" {
  name                       = "${var.prefix}-rule-ssh-brute-force"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "SSH Brute Force Detected"
  description                = "Five or more failed SSH authentication attempts from the same source IP within 5 minutes. Indicates a brute force or credential stuffing attack. Maps to T1110.001."
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

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["CredentialAccess"]
  techniques = ["T1110"]

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 2: Privilege Escalation via Sudo Group Add ─────────────────────────
# Detects a user being added to the sudo or wheel group, granting root-level
# access. Maps to T1548.003 (Abuse Elevation Control Mechanism: Sudo).
#
# On Ubuntu: "usermod -aG sudo <user>" produces authpriv syslog entries.
# False positives: Legitimate admin provisioning — consider scoping to
# non-admin accounts or alert + require investigation.

resource "azurerm_sentinel_alert_rule_scheduled" "sudo_group_add" {
  name                       = "${var.prefix}-rule-sudo-group-add"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "User Added to Sudo Group"
  description                = "A user was added to the sudo or wheel group, granting elevated privileges. Unexpected changes to privileged groups indicate a privilege escalation attempt. Maps to T1548.003."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "authpriv"
    | where SyslogMessage has_any ("to group sudo", "to group wheel", "added to group")
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation"]
  techniques = ["T1548"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 3: Persistence via Cron Job ────────────────────────────────────────
# Detects a new cron entry created by a non-root user. Attackers use cron to
# maintain persistence by scheduling malicious scripts to run repeatedly.
# Maps to T1053.003 (Scheduled Task/Job: Cron).
#
# On Ubuntu: editing crontab logs BEGIN EDIT/REPLACE to the cron facility.
# Root cron entries are filtered — focus on unexpected non-admin user activity.

resource "azurerm_sentinel_alert_rule_scheduled" "cron_persistence" {
  name                       = "${var.prefix}-rule-cron-persistence"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Cron Job Created by Non-Root User"
  description                = "A new cron job was written by a non-root user. Attackers schedule malicious scripts via cron to persist across reboots. Maps to T1053.003."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "cron"
    | where SyslogMessage has_any ("REPLACE", "new job", "BEGIN EDIT")
    | where SyslogMessage !has "root"
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Persistence"]
  techniques = ["T1053"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 4: New Local User Account Created ──────────────────────────────────
# Detects when a new user account is created on the workload VM.
# Attackers create accounts to establish persistence or enable future
# access even if their initial foothold is removed.
# Maps to T1136.001 (Create Account: Local Account).
#
# On Ubuntu: "useradd" and "adduser" write to authpriv. Look for
# "new user: name=..." pattern to distinguish from group creation events.

resource "azurerm_sentinel_alert_rule_scheduled" "new_local_account" {
  name                       = "${var.prefix}-rule-new-local-account"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "New Local User Account Created"
  description                = "A new local user account was created on the workload VM. Attackers create accounts to maintain persistence. Maps to T1136.001."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility in ("auth", "authpriv")
    | where SyslogMessage has_any ("new user:", "useradd[", "adduser[")
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Persistence"]
  techniques = ["T1136"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 5: Successful Root SSH Login ───────────────────────────────────────
# Detects a direct SSH login as the root user. Root login should be disabled
# in well-hardened environments (PermitRootLogin no in sshd_config). Any
# successful root login is high-priority — either a misconfiguration or
# an attacker who has already obtained root credentials.
# Maps to T1078 (Valid Accounts).

resource "azurerm_sentinel_alert_rule_scheduled" "root_ssh_login" {
  name                       = "${var.prefix}-rule-root-ssh-login"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Successful Root SSH Login"
  description                = "A direct SSH login as root was accepted. Root SSH login is unexpected in this environment. May indicate credential compromise or misconfiguration. Maps to T1078."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility in ("auth", "authpriv")
    | where SyslogMessage has "Accepted"
    | where SyslogMessage has "root"
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["DefenseEvasion", "Persistence", "PrivilegeEscalation", "InitialAccess"]
  techniques = ["T1078"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 6: Repeated Failed Sudo Attempts ───────────────────────────────────
# Detects multiple failed sudo authentication attempts from the same user,
# which can indicate an attacker attempting to escalate privileges via
# repeated password guessing on sudo. Complements Rule 2 (group add).
# Maps to T1548.003 (Abuse Elevation Control Mechanism: Sudo).
#
# On Ubuntu: failed sudo attempts log to authpriv as:
# "sudo: pam_unix(sudo:auth): authentication failure"

resource "azurerm_sentinel_alert_rule_scheduled" "sudo_brute_force" {
  name                       = "${var.prefix}-rule-sudo-brute-force"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Repeated Failed Sudo Attempts"
  description                = "Three or more failed sudo authentication attempts in 15 minutes from the same host. May indicate privilege escalation via password guessing. Maps to T1548.003."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "authpriv"
    | where SyslogMessage has "sudo"
    | where SyslogMessage has_any ("authentication failure", "incorrect password attempt")
    | summarize attempt_count = count() by Computer, HostIP, bin(TimeGenerated, 15m)
    | where attempt_count >= 3
    | project TimeGenerated, Computer, HostIP, attempt_count
  EOT

  query_frequency   = "PT15M"
  query_period      = "PT15M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["PrivilegeEscalation"]
  techniques = ["T1548"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 7: Syslog Daemon Stopped or Restarted ──────────────────────────────
# Detects the syslog/rsyslog daemon stopping or being restarted unexpectedly.
# Adversaries stop logging daemons to blind the monitoring pipeline before
# conducting further activity. Any unexpected syslog stop is high-priority
# because it directly breaks the detection pipeline.
# Maps to T1070.002 (Indicator Removal: Clear Linux/Mac System Logs).
#
# Note: If syslog stops, this rule may NOT fire for events after the stop.
# Consider pairing with a Log Analytics alert on "no data received in 30min"
# to detect complete logging gaps.

resource "azurerm_sentinel_alert_rule_scheduled" "syslog_daemon_stopped" {
  name                       = "${var.prefix}-rule-syslog-daemon-stopped"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Syslog Daemon Stopped or Restarted"
  description                = "The rsyslog or syslog daemon was stopped or restarted. Attackers stop logging to blind the detection pipeline before further activity. Maps to T1070.002."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility in ("daemon", "syslog")
    | where ProcessName in ("rsyslogd", "syslogd", "systemd")
    | where SyslogMessage has_any ("exiting on signal", "stopping", "Stopping rsyslog", "rsyslogd: HUP")
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["DefenseEvasion"]
  techniques = ["T1070"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 8: Account Password Changed ────────────────────────────────────────
# Detects when a user account password is changed. Attackers change passwords
# to lock out legitimate users or to maintain access to compromised accounts
# after the initial breach is discovered.
# Maps to T1098 (Account Manipulation).
#
# On Ubuntu: "passwd" and "chpasswd" write to authpriv.
# False positives: Routine password rotation — acceptable if this environment
# does not have scheduled password changes configured.

resource "azurerm_sentinel_alert_rule_scheduled" "account_password_changed" {
  name                       = "${var.prefix}-rule-account-password-changed"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Account Password Changed"
  description                = "A user account password was changed. Attackers modify passwords to lock out legitimate users or maintain persistent access. Maps to T1098."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "authpriv"
    | where SyslogMessage has_any ("password changed for", "chpasswd:", "passwd:")
    | where SyslogMessage has_any ("password changed", "updated password")
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Persistence"]
  techniques = ["T1098"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 9: Systemd Service Installed ───────────────────────────────────────
# Detects a new systemd service unit being enabled or started. Attackers install
# malicious services to survive reboots and maintain persistent execution.
# Maps to T1543.002 (Create or Modify System Process: Systemd Service).
#
# On Ubuntu: systemd logs to the daemon facility. "Created symlink" appears
# when a service is enabled (systemctl enable). Tune by adding known-good
# service names to the exclusion list as you observe them in your environment.

resource "azurerm_sentinel_alert_rule_scheduled" "systemd_service_installed" {
  name                       = "${var.prefix}-rule-systemd-service-installed"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "New Systemd Service Installed"
  description                = "A new systemd service unit was enabled or created. Attackers install services to maintain persistence across reboots. Maps to T1543.002."
  severity                   = "Medium"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where Facility == "daemon"
    | where ProcessName == "systemd"
    | where SyslogMessage has "Created symlink"
    | where SyslogMessage has ".service"
    | project TimeGenerated, Computer, HostIP, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Persistence"]
  techniques = ["T1543"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# ─── Rule 10: Reverse Shell Indicators ───────────────────────────────────────
# Detects common reverse shell patterns in syslog messages. Reverse shells
# are used by attackers to establish command-and-control channels from a
# compromised host back to an attacker-controlled server.
# Maps to T1059.004 (Command and Scripting Interpreter: Unix Shell).
#
# These patterns appear in syslog when a shell or related tool logs its
# invocation (e.g., via PAM, sudo, or a logging wrapper). Detection coverage
# is best-effort with syslog alone — auditd process execution logging would
# significantly improve fidelity. Treat any match as high-confidence.

resource "azurerm_sentinel_alert_rule_scheduled" "reverse_shell_indicators" {
  name                       = "${var.prefix}-rule-reverse-shell"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Reverse Shell Indicators Detected"
  description                = "Syslog contains patterns associated with reverse shell techniques: bash -i, /dev/tcp, or netcat in listener mode. Any match warrants immediate investigation. Maps to T1059.004."
  severity                   = "High"
  enabled                    = true

  query = <<-EOT
    Syslog
    | where SyslogMessage has_any ("bash -i", "/dev/tcp/", "nc -e /bin", "ncat -e", "mkfifo /tmp", "0>&1")
    | project TimeGenerated, Computer, HostIP, Facility, SyslogMessage
  EOT

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics    = ["Execution"]
  techniques = ["T1059"]

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "HostName"
      column_name = "Computer"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "HostIP"
    }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}
