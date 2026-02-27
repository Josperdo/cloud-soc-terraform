# Troubleshooting Guide

Common issues encountered when deploying and using this lab, with root causes and fixes.

---

## Terraform Deployment Issues

### `terraform apply` fails: "AuthorizationFailed"

**Symptom:**
```
Error: creating Resource Group: ... Code="AuthorizationFailed"
Message="The client ... does not have authorization to perform action
'Microsoft.Resources/subscriptions/resourcegroups/write'"
```

**Root cause:** Your Azure account does not have Owner on the subscription. This lab requires Owner (not just Contributor) because it creates an RBAC role assignment and an Azure Policy assignment — both of which need Owner-level permissions. On a free trial account you are Owner by default.

**Fix:**
```bash
# Check your current role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) -o table

# If you need to grant yourself Owner (requires an existing Owner or User Access Administrator):
az role assignment create \
  --assignee $(az account show --query user.name -o tsv) \
  --role Owner \
  --scope /subscriptions/<your-subscription-id>
```

---

### `terraform apply` fails: "ResourceProviderNotRegistered"

**Symptom:**
```
Error: ... Code="MissingSubscriptionRegistration"
Message="The subscription is not registered to use namespace 'Microsoft.SecurityInsights'"
```

**Root cause:** Azure resource providers must be registered before resources can be created. Terraform attempts this automatically, but it requires `*/register/action` permission.

**Fix:**
```bash
az provider register --namespace Microsoft.SecurityInsights --wait
az provider register --namespace Microsoft.Insights --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait

# Verify all are registered
az provider show --namespace Microsoft.SecurityInsights --query "registrationState" -o tsv
```

---

### `terraform apply` fails: Bastion host error during creation

**Symptom:**
```
Error: creating Bastion Host ... the operation failed with status: 'Failed'
```

**Root cause:** Azure Bastion provisioning occasionally fails transiently, especially if the subnet CIDR is wrong or the NSG is missing required rules.

**Fix:**
1. Verify `bastion_subnet_cidr` is `/26` or larger (Azure requires this)
2. Check the Bastion NSG — it must have the exact rules defined in `modules/network/main.tf`
3. If the CIDR and NSG are correct, run `terraform apply` again — Bastion provisioning is idempotent and the retry usually succeeds

---

### `terraform fmt -check` fails in CI

**Symptom:** GitHub Actions shows "Terraform files are not formatted correctly"

**Fix:**
```bash
# Auto-format all .tf files
terraform fmt -recursive

# Then commit and push
git add -A && git commit -m "fix: terraform fmt"
```

---

### `terraform validate` fails with "Unsupported argument"

**Symptom:**
```
Error: Unsupported argument
An argument named "entity_mapping" is not expected here.
```

**Root cause:** Terraform provider version is too old. `entity_mapping` on `azurerm_sentinel_alert_rule_scheduled` requires azurerm ~> 4.0.

**Fix:** Check `providers.tf` — the `azurerm` provider version constraint should be `~> 4.0`. Run `terraform init -upgrade` to pull the latest 4.x version.

---

## Log Analytics / Monitoring Issues

### Syslog table is empty — no logs from the VM

**Symptom:** The Syslog table returns no results for the last hour.

**Diagnosis steps:**

**Step 1:** Verify the AMA extension is installed on the VM:
```bash
az vm extension list \
  --resource-group <prefix>-soc-rg \
  --vm-name <prefix>-workload-vm \
  --output table
```
Look for `AzureMonitorLinuxAgent` in the output with `ProvisioningState = Succeeded`.

**Step 2:** Verify the Data Collection Rule association exists:
```bash
az monitor data-collection rule association list \
  --resource /subscriptions/<sub-id>/resourceGroups/<prefix>-soc-rg/providers/Microsoft.Compute/virtualMachines/<prefix>-workload-vm
```

**Step 3:** SSH into the VM and check AMA is running:
```bash
systemctl status azuremonitoragent
journalctl -u azuremonitoragent -n 50
```

If AMA is stopped, restart it: `sudo systemctl restart azuremonitoragent`

**Step 4:** Generate a test log and wait 5 minutes:
```bash
# Run on the VM
logger -p auth.info "test syslog message from lab"

# Then query in Log Analytics
# Syslog | where SyslogMessage has "test syslog message from lab"
```

**Step 5:** If still no logs after 10 minutes, check the DCR configuration:
```bash
az monitor data-collection rule show \
  --name <prefix>-dcr-linux-syslog \
  --resource-group <prefix>-soc-rg
```
Verify that `dataSources.syslog` contains the expected facilities.

---

### Logs appear in Log Analytics but Sentinel rules don't fire

**Symptom:** The Syslog table has data, but no alerts appear in Sentinel.

**Check 1:** Verify Sentinel is enabled on the workspace:
- Portal → Microsoft Sentinel → verify the workspace is listed

**Check 2:** Verify the analytics rules are enabled:
- Sentinel → Configuration → Analytics → find your rules → confirm "Enabled" toggle is on
- After `terraform apply`, rules should be enabled. If they show as disabled, try re-running apply.

**Check 3:** Check the rule's "Last run" time:
- Click a rule → View details → Look for "Last run" timestamp
- If it hasn't run in >10 minutes, the rule may have failed silently

**Check 4:** Run the rule's KQL manually:
- Copy the KQL from `modules/monitoring/analytics_rules.tf`
- Paste into Log Analytics → Logs
- Remove time filters and add `| where TimeGenerated >= ago(1h)`
- If it returns results, the rule should fire. If not, the trigger event didn't generate matching logs.

**Check 5:** Verify the Sentinel onboarding resource exists:
- Portal → Log Analytics workspace → Microsoft Sentinel blade should be present
- In Terraform state: `terraform state list | grep onboarding`

---

### Analytics rules show "depends on onboarding" error during apply

**Symptom:**
```
Error: creating Scheduled Alert Rule: ...
"Workspace ... is not onboarded to Microsoft Sentinel"
```

**Root cause:** Terraform is trying to create alert rules before the Sentinel onboarding resource is fully propagated. This occasionally happens on first deployment.

**Fix:** Run `terraform apply` again. The `depends_on` ensures ordering but Azure's API sometimes has propagation delays on first onboarding.

---

## Azure Bastion Issues

### "Unable to connect" when trying to SSH via Bastion in the portal

**Check 1:** Is the VM running?
```bash
az vm show -g <prefix>-soc-rg -n <prefix>-workload-vm --show-details --query "powerState" -o tsv
# Should return "VM running"
```

If stopped: `az vm start -g <prefix>-soc-rg -n <prefix>-workload-vm`

**Check 2:** Is the Bastion host in "Succeeded" provisioning state?
```bash
az network bastion show -g <prefix>-soc-rg -n <prefix>-bastion --query "provisioningState" -o tsv
```

**Check 3:** Are you using the correct username and SSH key?
- Default username: `azureadmin` (or whatever you set in `terraform.tfvars`)
- SSH private key: `~/.ssh/azure_soc_key` (the private half of the pair)
- In the portal Bastion connection dialog, upload or paste the **private** key content

**Check 4:** Bastion NSG rules — the Bastion subnet NSG must have specific rules. If you modified them, refer to the [Azure Bastion NSG requirements](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg).

---

### Bastion connects but VM immediately disconnects

**Root cause:** The VM may be in a bad state or the SSH daemon has crashed.

**Fix:** Use the Azure Portal's **Boot Diagnostics → Serial Console** to access the VM without SSH:
1. Portal → VM → Help → Serial Console
2. Log in with username/password (you'll need to set a temporary password first via `az vm user update`)

---

## Sentinel Detection Issues

### Rule fires but entities are blank in the incident

**Symptom:** An incident is created but the "Entities" section in the incident details shows nothing.

**Root cause:** The `entity_mapping` column name doesn't match the actual column output of the KQL query.

**Fix:**
1. Run the rule's KQL in Log Analytics manually
2. Verify the projected columns match the `column_name` values in `entity_mapping`
3. For example, `entity_mapping { field_mapping { column_name = "HostIP" } }` requires the query to output a column named exactly `HostIP`

---

### Rule 7 (Syslog Daemon Restart) never fires even after `sudo systemctl restart rsyslog`

**Root cause:** The restart happens too fast — the final syslog message from rsyslogd and the systemd state change may not be captured in the exact format the KQL filters for.

**Debug:**
```kql
Syslog
| where TimeGenerated >= ago(30m)
| where ProcessName in ("rsyslogd", "systemd")
| where Facility in ("daemon", "syslog")
| project TimeGenerated, ProcessName, Facility, SyslogMessage
| order by TimeGenerated desc
```

Review the actual message text and update the `has_any` list in the rule's KQL if the format differs on your VM's version of rsyslog or Ubuntu.

---

## Cost / Billing Issues

### Unexpected charges after the lab

**Most common cause:** You stopped the VM but didn't destroy the environment. Azure Bastion ($140/month) accrues charges even when the VM is stopped.

**Fix:**
```bash
# Destroy everything (all resources in the resource group)
terraform destroy
```

**How to verify everything is deleted:**
```bash
az resource list -g <prefix>-soc-rg -o table
# Should return "No resources found in <prefix>-soc-rg"
```

If the resource group itself remains after `terraform destroy`, delete it manually:
```bash
az group delete -n <prefix>-soc-rg --yes --no-wait
```

---

### `terraform destroy` fails partway through

**Root cause:** Resources with dependencies sometimes fail to delete in the right order, or Azure is holding a lock.

**Fix:**
1. Run `terraform destroy` again — it will retry failed resources
2. If still failing, delete manually from the portal and then run `terraform state rm <resource>` to remove it from state
3. As a last resort, delete the entire resource group from the portal:
   ```bash
   az group delete -n <prefix>-soc-rg --yes
   ```
   Then run `terraform destroy` to clean up the state file (it will confirm nothing exists).

---

## Getting Further Help

- **Terraform AzureRM docs:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Sentinel documentation:** https://learn.microsoft.com/en-us/azure/sentinel/
- **Azure Monitor Agent troubleshooting:** https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-troubleshoot-linux-vm
- **Log Analytics KQL reference:** https://learn.microsoft.com/en-us/azure/data-explorer/kql-quick-reference
- **Open an issue:** https://github.com/Josperdo/azure-soc-terraform/issues
