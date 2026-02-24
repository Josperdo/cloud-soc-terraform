# KQL Detection Rules Reference

All 10 detection rules deployed by this lab target the **Syslog** table in Log Analytics. This reference explains each rule's query logic, field choices, tuning guidance, and known false positive scenarios.

You can run any query here directly in **Log Analytics → Logs** to validate it against real data before the Sentinel rule fires.

---

## Syslog Table Schema

Understanding the key fields before reading the queries:

| Field | Type | Description |
|-------|------|-------------|
| `TimeGenerated` | datetime | When the log entry was received in Log Analytics |
| `Computer` | string | Hostname of the VM that sent the log |
| `HostIP` | string | IP address of the VM (private IP in this lab) |
| `Facility` | string | Syslog facility: auth, authpriv, cron, daemon, kern, syslog, user |
| `SeverityLevel` | string | warning, error, info, debug, etc. |
| `SyslogMessage` | string | The raw log message text |
| `ProcessName` | string | The process that generated the log (e.g., sshd, sudo, systemd) |
| `ProcessID` | int | PID of the process |

> **Tip:** The most useful field for detections is `SyslogMessage`. Always start a new detection by exploring raw message text with `| project SyslogMessage | take 100`.

---

## Rule 1 — SSH Brute Force (T1110.001)

**MITRE Tactic:** Credential Access
**Severity:** Medium
**Facility:** auth, authpriv
**Trigger:** ≥5 failed attempts from same IP in 5 minutes

```kql
Syslog
| where Facility in ("auth", "authpriv")
| where SyslogMessage has "Failed password"
| summarize attempt_count = count() by HostIP, bin(TimeGenerated, 5m)
| where attempt_count >= 5
| project TimeGenerated, HostIP, attempt_count
```

### How it works

`"Failed password"` is the exact string written by `sshd` on Ubuntu 22.04 for every failed password attempt. We summarize by `HostIP` (the VM's IP, used as a proxy for the source since we're looking at the host log) and a 5-minute time bin. The `attempt_count >= 5` filter eliminates occasional failed logins (users mistyping passwords once or twice).

### Why `has` instead of `contains`?

`has` performs whole-word matching and is significantly faster than `contains` on large datasets because it uses an inverted index. Always prefer `has` when matching complete words or phrases.

### Tuning guidance

- **Too noisy (false positives from legitimate failed logins)?**
  Add: `| where SyslogMessage !has "azureadmin"` to exclude the known admin account
- **Missing slow attacks (< 5 attempts per 5 min)?**
  Change `query_period` to `PT1H` and `trigger_threshold` to `10` in Terraform
- **Want to distinguish attack source IPs?**
  The sshd message contains the source IP: `| extend SourceIP = extract("from ([0-9.]+)", 1, SyslogMessage)`

### Known false positives

- A user repeatedly mistyping their password from a jump host
- Automated scripts or monitoring tools that attempt SSH health checks

---

## Rule 2 — Sudo Group Add (T1548.003)

**MITRE Tactic:** Privilege Escalation
**Severity:** High
**Facility:** authpriv
**Trigger:** Any match (any user added to sudo/wheel group)

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has_any ("to group sudo", "to group wheel", "added to group")
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

On Ubuntu, running `usermod -aG sudo <user>` writes a PAM/auth log entry via the `pam_unix` module. The message contains "to group sudo". The `wheel` group is the equivalent on Red Hat/CentOS systems, included for broader coverage.

### Why `has_any`?

`has_any(list)` is shorthand for `has "a" or has "b" or ...`. Slightly more readable and equally performant.

### Tuning guidance

- **Expected provisioning automation (e.g., Ansible adding admins)?**
  Add: `| where Computer !in ("known-automation-host")` or add a time-based exception for deployment windows
- **Want to extract the affected username?**
  Add: `| extend AffectedUser = extract("member '([^']+)'", 1, SyslogMessage)`

### Known false positives

- New admin account provisioning during setup
- Configuration management tools that manage group membership

---

## Rule 3 — Cron Persistence (T1053.003)

**MITRE Tactic:** Persistence
**Severity:** Medium
**Facility:** cron
**Trigger:** Any non-root crontab modification

```kql
Syslog
| where Facility == "cron"
| where SyslogMessage has_any ("REPLACE", "new job", "BEGIN EDIT")
| where SyslogMessage !has "root"
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

When a user runs `crontab -e`, the `cron` daemon logs `BEGIN EDIT` and `REPLACE` events to syslog. `new job` appears when a new cron entry is added. We exclude `root` since root cron jobs are expected (system maintenance, log rotation, etc.).

### Tuning guidance

- **Legitimate non-root cron jobs exist in your environment?**
  Add: `| where SyslogMessage !has "backup-user"` to exclude known accounts
- **Want to capture root cron changes too?**
  Remove the `!has "root"` line and treat any cron modification as notable

### Known false positives

- Application users with legitimate scheduled jobs (backups, report generation)
- Monitoring agent update mechanisms

---

## Rule 4 — New Local User Account (T1136.001)

**MITRE Tactic:** Persistence
**Severity:** High
**Facility:** auth, authpriv
**Trigger:** Any new user account creation

```kql
Syslog
| where Facility in ("auth", "authpriv")
| where SyslogMessage has_any ("new user:", "useradd[", "adduser[")
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

`useradd` (direct tool) and `adduser` (higher-level wrapper on Ubuntu) both write to the auth/authpriv facility. The `new user:` pattern appears in the PAM log entry for account creation, including the UID/GID of the new account.

### Tuning guidance

- **Initial VM setup creates multiple users?**
  Add a time-based filter: `| where TimeGenerated > datetime("2025-01-01")` to ignore pre-baseline accounts
- **Want to extract the new username?**
  Add: `| extend NewUser = extract("new user: name=([^,]+)", 1, SyslogMessage)`

### Known false positives

- Service accounts created by software installation (`apt install` can create system users)
- Known automation that provisions users as part of configuration management

---

## Rule 5 — Successful Root SSH Login (T1078)

**MITRE Tactics:** Defense Evasion, Persistence, Privilege Escalation, Initial Access
**Severity:** High
**Facility:** auth, authpriv
**Trigger:** Any successful root login

```kql
Syslog
| where Facility in ("auth", "authpriv")
| where SyslogMessage has "Accepted"
| where SyslogMessage has "root"
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

`sshd` writes `"Accepted publickey for root from <ip>"` or `"Accepted password for root from <ip>"` on successful authentication. Ubuntu 22.04 defaults to `PermitRootLogin prohibit-password` — root login with a key is still possible. This rule catches it.

### Why four MITRE tactics?

A root SSH login simultaneously achieves multiple attacker goals: it grants persistent access (Persistence), bypasses access controls (Defense Evasion), gives highest privilege immediately (Privilege Escalation), and if from an external IP, represents a new foothold (Initial Access).

### Tuning guidance

This rule has `trigger_threshold = 0` — any match fires. Root SSH login should be zero in a well-configured environment. If you get a false positive, investigate the source IP before adding an exclusion.

### Known false positives

- Emergency access during incident response
- Break-glass accounts in organizations that allow root SSH as a last resort

---

## Rule 6 — Repeated Failed Sudo Attempts (T1548.003)

**MITRE Tactic:** Privilege Escalation
**Severity:** Medium
**Facility:** authpriv
**Trigger:** ≥3 failed sudo attempts in 15 minutes from same host

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has "sudo"
| where SyslogMessage has_any ("authentication failure", "incorrect password attempt")
| summarize attempt_count = count() by Computer, HostIP, bin(TimeGenerated, 15m)
| where attempt_count >= 3
| project TimeGenerated, Computer, HostIP, attempt_count
```

### How it works

PAM writes `pam_unix(sudo:auth): authentication failure` when a sudo password is wrong. We summarize by host (not IP) here since these are local attempts — the attacker is already on the machine and trying to escalate from a non-privileged account.

### Relationship to Rule 2

Rule 2 detects *successful* privilege escalation (user added to sudo group). Rule 6 detects *attempted* privilege escalation via password guessing. Together they cover the full sudo attack surface.

### Tuning guidance

- **Users frequently forget their sudo password?**
  Increase threshold to 5, or change `query_period` to `PT30M` for a wider window
- **Want per-user tracking?**
  Add: `| extend UserName = extract("for user ([^ ]+)", 1, SyslogMessage)` and group by it

### Known false positives

- Users who use sudo infrequently and forget their password
- Scripts that attempt sudo without a tty available

---

## Rule 7 — Syslog Daemon Stopped or Restarted (T1070.002)

**MITRE Tactic:** Defense Evasion
**Severity:** High
**Facility:** daemon, syslog
**Trigger:** Any syslog service stop/restart event

```kql
Syslog
| where Facility in ("daemon", "syslog")
| where ProcessName in ("rsyslogd", "syslogd", "systemd")
| where SyslogMessage has_any ("exiting on signal", "stopping", "Stopping rsyslog", "rsyslogd: HUP")
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

When `rsyslogd` is stopped (via `systemctl stop rsyslog` or `kill`), it writes a final message to syslog before exiting. systemd also logs the service state change to the daemon facility. This rule catches both.

### The inherent limitation

If an attacker kills syslog *without* it writing a final message (e.g., `kill -9 $(pgrep rsyslogd)`), no event will be logged and this rule won't fire. Consider pairing with a Log Analytics **alert on low data volume**: if the Syslog table receives fewer than N events in M minutes from the VM, alert. This covers the "complete silence" scenario.

### Known false positives

- Scheduled system updates that restart syslog
- Kernel module loading that causes syslog to restart

---

## Rule 8 — Account Password Changed (T1098)

**MITRE Tactic:** Persistence
**Severity:** Medium
**Facility:** authpriv
**Trigger:** Any password change event

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has_any ("password changed for", "chpasswd:", "passwd:")
| where SyslogMessage has_any ("password changed", "updated password")
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

`passwd` (interactive) and `chpasswd` (non-interactive bulk change) both write to authpriv. The double `has_any` filters on both the process name and the action to reduce false positives from other `passwd:` entries (like PAM configuration messages).

### Tuning guidance

- **Scheduled password rotation generates noise?**
  Exclude during known maintenance windows or add `| where SyslogMessage !has "admin-rotation-script"`
- **Want to track which account was changed?**
  Add: `| extend ChangedAccount = extract("password changed for (.+)$", 1, SyslogMessage)`

### Known false positives

- Legitimate password changes by users
- Automated password rotation scripts

---

## Rule 9 — Systemd Service Installed (T1543.002)

**MITRE Tactic:** Persistence
**Severity:** Medium
**Facility:** daemon
**Trigger:** Any new `.service` symlink created by systemd

```kql
Syslog
| where Facility == "daemon"
| where ProcessName == "systemd"
| where SyslogMessage has "Created symlink"
| where SyslogMessage has ".service"
| project TimeGenerated, Computer, HostIP, SyslogMessage
```

### How it works

`systemctl enable <service>` creates a symlink in `/etc/systemd/system/multi-user.target.wants/` (or similar). systemd logs this as `"Created symlink /etc/systemd/system/... → ..."`. We filter on `.service` to exclude timer and socket unit type noise.

### Tuning guidance

- **Initial system setup creates many services?**
  Add known-good services to an exclusion list:
  ```kql
  | where SyslogMessage !has_any ("snap.", "apt-daily", "fwupd", "motd-news")
  ```
- **Want to extract the service name?**
  Add: `| extend ServiceName = extract("symlink .+ → .+/([^/]+\\.service)$", 1, SyslogMessage)`

### Known false positives

- Package installations that install and enable system services (`apt install` of any daemon)
- Ubuntu snap packages creating service units

---

## Rule 10 — Reverse Shell Indicators (T1059.004)

**MITRE Tactic:** Execution
**Severity:** High
**Facility:** Any
**Trigger:** Any match (treat every result as high-confidence)

```kql
Syslog
| where SyslogMessage has_any ("bash -i", "/dev/tcp/", "nc -e /bin", "ncat -e", "mkfifo /tmp", "0>&1")
| project TimeGenerated, Computer, HostIP, Facility, SyslogMessage
```

### How it works

Common reverse shell patterns (`bash -i >& /dev/tcp/...`, `nc -e /bin/bash`, `mkfifo /tmp/pipe`) rarely appear in legitimate syslog messages. This rule runs without facility filtering — if any log message contains these strings, it's likely significant.

### Coverage limitation

Syslog captures these patterns only when a process explicitly logs them or when a parent process (like PAM, sudo, or a shell wrapper) logs the command. For deeper coverage of command execution, consider enabling **auditd** with process execution rules, or deploying **Defender for Endpoint** on the VM. This rule is best-effort for a syslog-only environment.

### Tuning guidance

This rule should not need tuning — the patterns are very specific to attack tooling. A false positive here is extremely unlikely and still warrants investigation.

---

## Adding Your Own Rules

To add a new rule:

1. Write and validate the KQL in Log Analytics → Logs against real data
2. Add a new `azurerm_sentinel_alert_rule_scheduled` block to `modules/monitoring/analytics_rules.tf`
3. Follow the existing naming pattern: `<prefix>-rule-<short-description>`
4. Include:
   - `depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]`
   - At least one `entity_mapping` block
   - `tactics` and `techniques` arrays with MITRE values
5. Run `terraform fmt -recursive` and `terraform plan` before applying

### KQL development tips

```kql
-- Explore a new log type: see what messages exist
Syslog
| where TimeGenerated >= ago(24h)
| where Facility == "auth"
| project SyslogMessage
| take 200

-- Find the right filter string
Syslog
| where SyslogMessage contains "password"
| distinct SyslogMessage
| take 50

-- Test a detection pattern against historical data
Syslog
| where TimeGenerated >= ago(7d)
| where SyslogMessage has "Failed password"
| summarize count() by bin(TimeGenerated, 1d)
-- Check: is the daily count sane, or are there suspicious spikes?
```
