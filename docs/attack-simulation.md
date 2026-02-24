# Attack Simulation Playbook

This playbook contains the exact commands to trigger each Sentinel detection rule deployed in this lab. Run them from an SSH session on the workload VM via Azure Bastion.

> **Important:** These are authorized simulations on a lab environment you own. Never run these commands on systems you don't own or without written authorization.

---

## Before You Start

### Connect to the VM

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to your resource group → the Ubuntu VM → **Connect → Bastion**
3. Enter your admin username (default: `azureadmin`) and your SSH private key
4. Click **Connect** — a browser-based terminal opens

Alternatively, use the Azure CLI:

```bash
az network bastion ssh \
  --name <prefix>-bastion \
  --resource-group <prefix>-soc-rg \
  --target-resource-id /subscriptions/<sub-id>/resourceGroups/<prefix>-soc-rg/providers/Microsoft.Compute/virtualMachines/<prefix>-workload-vm \
  --auth-type ssh-key \
  --username azureadmin \
  --ssh-key ~/.ssh/azure_soc_key
```

### Verify logs are flowing first

In Log Analytics → Logs, run this before simulating any attacks:

```kql
Syslog
| where TimeGenerated >= ago(5m)
| summarize count() by Facility
```

If `auth` and `authpriv` are in the results, the pipeline is healthy. If not, see [Troubleshooting](troubleshooting.md).

### Expected timeline

After running a simulation command:
- **1–3 min**: The log event appears in Log Analytics (Syslog table)
- **5–10 min**: Sentinel's scheduled rule fires and creates an alert
- **Up to 10 min**: The alert groups into an incident

---

## Simulation 1 — SSH Brute Force (T1110.001)

**Rule:** SSH Brute Force Detected | Severity: Medium

This simulates a brute force attack from an external IP by generating failed SSH authentication attempts directly on the VM using `ssh` with wrong passwords.

### Run on the VM

```bash
# Generate 6 failed SSH login attempts against localhost
# (-o StrictHostKeyChecking=no to avoid host key prompts)
for i in $(seq 1 6); do
  ssh -o StrictHostKeyChecking=no \
      -o ConnectTimeout=3 \
      -o BatchMode=yes \
      azureadmin@127.0.0.1 \
      "echo test" 2>/dev/null || true
done
echo "Done. Wait 5-10 minutes then check Sentinel."
```

This generates 6 "Failed password" (or "Connection refused") entries in `/var/log/auth.log` which AMA forwards to Log Analytics.

### Verify the log arrived (Log Analytics)

```kql
Syslog
| where Facility in ("auth", "authpriv")
| where SyslogMessage has "Failed password"
| where TimeGenerated >= ago(15m)
| project TimeGenerated, HostIP, SyslogMessage
| order by TimeGenerated desc
```

Expect 6 rows. If you see them, the detection rule will fire within one query cycle (~5 minutes).

### Clean up

No cleanup needed — these are ephemeral log entries.

---

## Simulation 2 — Privilege Escalation: Sudo Group Add (T1548.003)

**Rule:** User Added to Sudo Group | Severity: High

This simulates an attacker adding a newly created account to the sudo group to gain root-level access.

### Run on the VM (requires sudo)

```bash
# Create a test user
sudo useradd -m sim-attacker

# Add them to the sudo group (this is the trigger)
sudo usermod -aG sudo sim-attacker

echo "Done. Check /var/log/auth.log for 'to group sudo' then wait for Sentinel."
```

### Verify the log arrived

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has_any ("to group sudo", "to group wheel", "added to group")
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up (important — remove the test account)

```bash
sudo userdel -r sim-attacker
```

---

## Simulation 3 — Persistence: Cron Job (T1053.003)

**Rule:** Cron Job Created by Non-Root User | Severity: Medium

This simulates an attacker installing a cron job under a non-privileged user to execute a script on a schedule.

### Run on the VM

```bash
# Create a test user to simulate attacker account
sudo useradd -m sim-cronjob

# Switch to the test user and install a cron job
sudo -u sim-cronjob crontab -e
```

When the editor opens, add this line and save (Ctrl+X in nano, `:wq` in vim):

```
* * * * * echo "persistence" >> /tmp/sim-cron.log
```

Alternatively, inject non-interactively:

```bash
sudo -u sim-cronjob bash -c 'echo "* * * * * echo persistence >> /tmp/sim-cron.log" | crontab -'
echo "Cron installed. Check Sentinel in 5-10 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility == "cron"
| where SyslogMessage has_any ("REPLACE", "new job", "BEGIN EDIT")
| where SyslogMessage !has "root"
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up

```bash
sudo -u sim-cronjob crontab -r
sudo userdel -r sim-cronjob
rm -f /tmp/sim-cron.log
```

---

## Simulation 4 — Persistence: New User Account (T1136.001)

**Rule:** New Local User Account Created | Severity: High

This simulates an attacker creating a backdoor account for persistent access.

### Run on the VM

```bash
# Create a suspicious new account
sudo useradd -m -s /bin/bash backdoor-user
echo "User created. Check Sentinel in 5-10 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility in ("auth", "authpriv")
| where SyslogMessage has_any ("new user:", "useradd[")
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up

```bash
sudo userdel -r backdoor-user
```

---

## Simulation 5 — Defense Evasion: Syslog Daemon Restart (T1070.002)

**Rule:** Syslog Daemon Stopped or Restarted | Severity: High

This simulates an attacker restarting syslog to roll log files or cover tracks. Note: restarting (not killing) the daemon will still generate a record that Sentinel can detect.

> **Warning:** There is a brief window (seconds) after `systemctl stop rsyslog` during which logs are NOT forwarded. This is intentional — it demonstrates why this is a high-severity alert.

### Run on the VM

```bash
# Restart rsyslog (generates stop + start events)
sudo systemctl restart rsyslog
echo "rsyslog restarted. The stop event should be in Sentinel in 5-10 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility in ("daemon", "syslog")
| where ProcessName in ("rsyslogd", "systemd")
| where SyslogMessage has_any ("exiting", "stopping", "Stopping rsyslog", "Started rsyslog")
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, ProcessName, SyslogMessage
```

### Clean up

No cleanup needed.

---

## Simulation 6 — Privilege Escalation: Multiple Failed Sudo (T1548.003)

**Rule:** Repeated Failed Sudo Attempts | Severity: Medium

This simulates an attacker trying to escalate privileges via repeated sudo attempts with wrong passwords.

### Run on the VM

```bash
# Generate 4 failed sudo attempts (threshold is 3 in 15 minutes)
for i in $(seq 1 4); do
  echo "wrongpassword" | sudo -S -k ls 2>/dev/null || true
  sleep 2
done
echo "Done. Sentinel should alert within 15 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has "sudo"
| where SyslogMessage has_any ("authentication failure", "incorrect password attempt")
| where TimeGenerated >= ago(20m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up

No cleanup needed.

---

## Simulation 7 — Persistence: Systemd Service (T1543.002)

**Rule:** New Systemd Service Installed | Severity: Medium

This simulates an attacker installing a malicious persistence mechanism as a systemd service.

### Run on the VM

```bash
# Create a fake malicious service file
sudo tee /etc/systemd/system/sim-malware.service > /dev/null <<EOF
[Unit]
Description=Simulation Service

[Service]
ExecStart=/bin/sleep 3600

[Install]
WantedBy=multi-user.target
EOF

# Enable it (this creates the symlink that triggers the rule)
sudo systemctl enable sim-malware.service
echo "Service enabled. Check Sentinel in 5-10 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility == "daemon"
| where ProcessName == "systemd"
| where SyslogMessage has "Created symlink"
| where SyslogMessage has ".service"
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up

```bash
sudo systemctl disable sim-malware.service
sudo rm /etc/systemd/system/sim-malware.service
sudo systemctl daemon-reload
```

---

## Simulation 8 — Defense Evasion / Persistence: Password Change (T1098)

**Rule:** Account Password Changed | Severity: Medium

This simulates an attacker changing an account's password after compromising it, to lock out the legitimate user.

### Run on the VM

```bash
# Create a target account
sudo useradd -m sim-victim

# Change their password (this is the trigger)
echo "sim-victim:NewP@ssw0rd!" | sudo chpasswd
echo "Password changed. Check Sentinel in 5-10 minutes."
```

### Verify the log arrived

```kql
Syslog
| where Facility == "authpriv"
| where SyslogMessage has_any ("password changed for", "chpasswd:")
| where TimeGenerated >= ago(15m)
| project TimeGenerated, Computer, SyslogMessage
```

### Clean up

```bash
sudo userdel -r sim-victim
```

---

## Checking Incidents in Sentinel

After running simulations, check for generated incidents:

1. Open [Microsoft Sentinel](https://portal.azure.com) → your workspace
2. Navigate to **Threat Management → Incidents**
3. Filter by **Severity** (High, Medium) and **Time** (last 24 hours)
4. Click an incident to:
   - See the alert details and raw KQL results
   - Explore entity timelines (click a Host or IP entity)
   - Review the MITRE technique tag
   - Set status to "Closed" after investigation (to keep the queue clean)

### Check all active alerts (even if not grouped into incidents yet)

```kql
SecurityAlert
| where TimeGenerated >= ago(24h)
| project TimeGenerated, AlertName, AlertSeverity, Description
| order by TimeGenerated desc
```

---

## Full Lab Run Checklist

```
[ ] Deploy infrastructure (terraform apply)
[ ] Verify logs are flowing (Syslog query in Log Analytics)
[ ] Connect to VM via Bastion
[ ] Simulation 1: SSH Brute Force      → Rule 1 fires
[ ] Simulation 2: Sudo Group Add       → Rule 2 fires
[ ] Simulation 3: Cron Job             → Rule 3 fires
[ ] Simulation 4: New User Account     → Rule 4 fires
[ ] Simulation 5: Syslog Restart       → Rule 7 fires
[ ] Simulation 6: Failed Sudo          → Rule 6 fires
[ ] Simulation 7: Systemd Service      → Rule 9 fires
[ ] Simulation 8: Password Change      → Rule 8 fires
[ ] Check Sentinel Incidents panel
[ ] Open SOC Detection Dashboard workbook
[ ] Investigate at least one incident end-to-end
[ ] Clean up all test accounts/services
[ ] terraform destroy (to stop billing)
```
