# Lab Guide — Azure SOC Terraform

This guide walks you through the entire lab from zero to a working, detection-capable cloud SOC. It's layered: follow the numbered sections in order if you're new to any of these topics, or jump to the section you need if you already have context.

---

## Learning Objectives

By the end of this lab you will be able to:

- Deploy a secure Azure network using Terraform modules (no public VM IPs, Bastion access, least-privilege NSGs)
- Explain *why* each architectural security decision was made, not just what it does
- Understand how Linux syslog flows from a VM through Azure Monitor Agent → Data Collection Rule → Log Analytics → Sentinel
- Read, understand, and tune a KQL detection rule
- Map a detection rule to the MITRE ATT&CK framework
- Simulate a real attack technique and verify that Sentinel generates an incident

---

## Section 0 — Prerequisites and Cost

### Tools you need

| Tool | Why | Install |
|------|-----|---------|
| Terraform >= 1.5 | Deploys all Azure resources | [hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | Authenticates Terraform to Azure | [learn.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| An Azure subscription | Hosts all resources | Free trial or pay-as-you-go |
| SSH key pair | Authenticates to the VM (no passwords) | `ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_soc_key` |
| Git | Clone and fork the repo | [git-scm.com](https://git-scm.com/) |

### Azure account permissions

You need **Contributor** or **Owner** on the subscription. Contributor is sufficient for all resource deployments. Owner is required only if you want to assign RBAC roles (not needed for this lab's default configuration).

### Cost estimate

| Resource | ~Monthly cost | Notes |
|----------|--------------|-------|
| Azure Bastion Basic | ~$140 | Largest cost — destroy when not using |
| Standard_B2s VM | ~$30 | Stop the VM when idle |
| Log Analytics | ~$2–5 | Minimal data ingestion |
| Standard Public IP | ~$4 | Attached to Bastion |
| VNet, NSGs, Identity | $0 | Free |

**Total: ~$176–179/month running 24/7.** Realistically much less if you destroy the environment between sessions.

> **Cost control:** Run `terraform destroy` between lab sessions. Re-deploying takes 8–12 minutes. Alternatively, just stop the VM in the portal to eliminate compute costs, and the Bastion will stay ready.

### Register Azure resource providers

Terraform will attempt to register these automatically, but if it fails:

```bash
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.Insights
```

---

## Section 1 — Fork, Configure, and Deploy

### 1a. Fork the repository

1. Click **Fork** in the top-right of the GitHub repository page
2. Clone your fork: `git clone https://github.com/<your-username>/azure-soc-terraform.git`
3. Create a working branch: `git checkout -b lab/my-deployment`

**What to customize (safe to change):**

| Variable | Default | Change it to |
|----------|---------|-------------|
| `prefix` | `"soc"` | Any 2–6 lowercase alphanumeric string |
| `location` | `"East US"` | Any Azure region close to you |
| `vm_size` | `"Standard_B2s"` | `"Standard_B1s"` to cut cost ~50% |
| `log_retention_days` | `30` | 30–90 for free tier; up to 730 |
| `bastion_sku` | `"Basic"` | Leave as Basic for the lab |

**What NOT to change without understanding it first:**

| File/Resource | Why it's sensitive |
|---|---|
| NSG rules in `modules/network/main.tf` | Removing the "DenyInternetInbound" rules would expose the VM |
| `disable_password_authentication = true` in `modules/compute/main.tf` | Re-enabling password auth would make the VM vulnerable to brute force |
| AzureBastionSubnet CIDR | Azure requires exactly `/26` or larger for Bastion; changing it breaks deployment |
| Bastion NSG rules | Azure enforces specific inbound/outbound rules for Bastion to work |

### 1b. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — required fields:

```hcl
subscription_id      = "<your-subscription-id>"          # az account show --query id -o tsv
admin_ssh_public_key = "<contents of ~/.ssh/azure_soc_key.pub>"
```

Optional overrides:
```hcl
prefix   = "lab"        # short, lowercase, no spaces
location = "West US 2"  # pick a region close to you
vm_size  = "Standard_B1s"  # smaller = cheaper
```

### 1c. Deploy

```bash
az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform plan -out=soc.tfplan   # review carefully
terraform apply soc.tfplan
```

Deployment takes **8–12 minutes**. Azure Bastion is the bottleneck.

After apply, note the outputs — you'll use `log_analytics_workspace_id` and `vm_private_ip` later.

### 1d. Verify the deployment

In the Azure Portal:
1. **Resource Group** → find `<prefix>-soc-rg` → confirm ~18 resources are present
2. **Virtual Network** → confirm 3 subnets exist with NSGs attached
3. **Microsoft Sentinel** → confirm it's enabled on the Log Analytics workspace
4. **Sentinel → Analytics** → confirm the 10 detection rules are listed (some may show "No events")

---

## Section 2 — Architecture Deep-Dive: Why These Decisions?

This section explains the security *reasoning* behind each component. Understanding the why is more valuable than memorizing the what.

### Why Azure Bastion instead of a public IP + SSH?

**The problem with public IP + SSH:**
Direct SSH exposure means your VM is reachable by every scanner and bot on the internet. Even with strong passwords disabled, attackers can probe for misconfigured SSH options, attempt known CVEs against the SSH daemon, and generate enormous amounts of log noise. Many organizations have had VMs compromised because someone accidentally opened port 22 to the internet.

**What Azure Bastion does:**
Bastion acts as a hardened jump host managed entirely by Microsoft. You connect via HTTPS (443) in your browser — no SSH port is exposed. Your VM has no public IP at all. The attack surface shrinks dramatically.

**The trade-off:**
Bastion costs ~$140/month at Basic SKU. For a lab, that's the biggest cost. In production, this is worth it. For extended lab use, destroy the environment when not in use.

### Why three separate subnets with separate NSGs?

**Network segmentation** means a compromise in one zone doesn't automatically spread to others.

- **AzureBastionSubnet**: Microsoft's Bastion service runs here. Its NSG is strictly defined by Azure — you can't change it much. It allows HTTPS from the internet (for browser connections) and denies everything else inbound.
- **management-subnet**: Reserved for future management tools (Ansible, scripts). Only the Bastion subnet can SSH in. No internet inbound.
- **workload-subnet**: Where the Ubuntu VM lives. SSH only from the Bastion subnet. No internet inbound. The `Deny-Internet-Inbound` rule is explicit.

If someone compromised the workload VM, they could not SSH from it to the management subnet (outbound to management isn't permitted either). Defense-in-depth.

### Why a system-assigned managed identity on the VM?

**The problem with credentials:**
Traditional approaches store a service principal client ID + secret in a config file or environment variable on the VM. If an attacker reads that file, they have the identity.

**Managed identity:**
Azure automatically creates an identity for the VM, bound to its lifecycle. The VM gets tokens via the Azure Instance Metadata Service (IMDS endpoint at `169.254.169.254`) — no static credentials, no file to steal. The token is only available from inside the VM, has a short TTL, and is rotated automatically.

**How it's used here:**
The Azure Monitor Agent (AMA) uses the VM's managed identity to authenticate to Log Analytics and ship logs — no secrets, no keys.

### Why Azure Monitor Agent (AMA) instead of the old Log Analytics Agent?

The legacy Log Analytics Agent (also called MMA or OMS agent) is **deprecated as of August 2024**. AMA is the replacement. Key differences:
- AMA uses Data Collection Rules (DCRs) — explicit, auditable configs for what data to collect
- AMA authenticates via managed identity (no workspace keys stored on VM)
- AMA is more efficient and scales better across large VM fleets
- DCRs can be shared across multiple VMs and workspaces

### Why Terraform modules instead of a flat file?

A single `main.tf` with 50+ resources works but becomes unmaintainable. Modules enforce:
- **Separation of concerns**: `network/` only knows about networking; `compute/` only knows about the VM
- **Reusability**: You could deploy two workload VMs by calling the compute module twice
- **Testability**: Modules can be tested independently
- **Readability**: The root `main.tf` reads like an architecture diagram

---

## Section 3 — Terraform Module Walkthrough

### How the modules depend on each other

```
providers.tf
    ↓
variables.tf  ←── terraform.tfvars (your config)
    ↓
main.tf
    ├── module.resource_group   (no dependencies)
    ├── module.network          (depends on: resource_group)
    ├── module.compute          (depends on: resource_group, network)
    ├── module.bastion          (depends on: resource_group, network)
    └── module.monitoring       (depends on: resource_group, compute)
```

Terraform builds an implicit dependency graph from these references. It deploys resource_group first, then network in parallel with nothing else (since it's the next dependency), then compute + bastion in parallel (both only need network), then monitoring last (needs compute).

### Reading a module's interface

Every module has three files:

| File | Purpose |
|------|---------|
| `variables.tf` | The module's *inputs* — what the caller must provide |
| `main.tf` | The actual resource definitions |
| `outputs.tf` | What the module *exports* — values other modules can use |

Example — how the root `main.tf` wires modules together:

```hcl
module "compute" {
  source = "./modules/compute"

  vm_name   = "${var.prefix}-workload-vm"
  subnet_id = module.network.workload_subnet_id   # <-- output from network module
  ...
}
```

`module.network.workload_subnet_id` means: "go to the `network` module's `outputs.tf`, find the output named `workload_subnet_id`, use its value here." This is how Terraform knows network must deploy before compute.

### Key resource naming pattern

All resources follow: `<prefix>-<purpose>-<type>`. For example:
- `soc-workload-vm` — the VM
- `soc-bastion-pip` — the Bastion's public IP
- `soc-law` — the Log Analytics workspace

The `prefix` variable (default: `"soc"`) lets multiple people deploy this lab into the same subscription without name collisions.

---

## Section 4 — The Monitoring Pipeline

Understanding how a syslog message travels from the VM to a Sentinel incident is essential for detection engineering.

### The full pipeline

```
Ubuntu 22.04 VM
    │
    │ rsyslog writes to /var/log/auth.log, /var/log/syslog, etc.
    ▼
Azure Monitor Agent (AMA)
    │
    │ Reads logs matching the Data Collection Rule (DCR) configuration
    │ Authenticates to Azure using the VM's managed identity
    ▼
Data Collection Rule (DCR)
    │
    │ Defines WHICH facilities and severities to forward:
    │   Facilities: auth, authpriv, cron, daemon, kern, syslog, user
    │   Severities: all (debug → emergency)
    ▼
Log Analytics Workspace
    │
    │ Stores logs in the Syslog table
    │ Queryable via KQL immediately on ingestion
    ▼
Microsoft Sentinel
    │
    │ Scheduled analytics rules run KQL queries every 5–15 minutes
    │ If a query returns results, Sentinel creates an Alert
    │ Alerts are grouped into Incidents
    ▼
Incident
    │ Appears in Sentinel → Incidents
    │ Contains entity links (Host, IP) from entity_mapping
    └─ Ready for analyst investigation
```

### Typical ingestion latency

- Log written on VM → Log Analytics: **30 seconds to 3 minutes**
- Log Analytics → Sentinel analytics rule fires: up to **5 minutes** (the rule's `query_frequency`)
- **Total end-to-end: 1–8 minutes** after the triggering event

This means if you run an attack simulation, give it up to 10 minutes before expecting an incident in Sentinel.

### Checking if logs are flowing

In Log Analytics → Logs, run:

```kql
Syslog
| where TimeGenerated >= ago(1h)
| summarize count() by Facility
```

If you see rows for `auth`, `authpriv`, `cron`, etc., logs are flowing. If the table is empty, see the [Troubleshooting Guide](troubleshooting.md).

---

## Section 5 — Detection Engineering 101

### Reading a KQL detection rule

Here's Rule 1 (SSH Brute Force) with annotations:

```kql
Syslog                                          -- query the Syslog table
| where Facility in ("auth", "authpriv")        -- SSH auth events use these facilities
| where SyslogMessage has "Failed password"     -- the exact sshd log message on Ubuntu
| summarize attempt_count = count()             -- count events...
    by HostIP, bin(TimeGenerated, 5m)           -- ...per source IP per 5-minute window
| where attempt_count >= 5                      -- only alert if ≥5 failures
| project TimeGenerated, HostIP, attempt_count  -- output only the columns we need
```

**Key design decisions in this rule:**

- We use `has` instead of `contains` — `has` is faster (checks whole word boundaries)
- We bin by 5 minutes to match the rule's `query_period` (no lookback gaps)
- We project only the columns we need — keeps incident details clean
- The `entity_mapping` on this rule maps `HostIP` to an IP entity in Sentinel, so clicking the incident gives you a clickable IP with a full timeline

### MITRE ATT&CK mapping

Every rule in this lab maps to a MITRE technique. The mapping tells you:

- **What the attacker is trying to do** (the tactic)
- **How they're doing it** (the technique)
- **What other detections you might add** (browse adjacent techniques at [attack.mitre.org](https://attack.mitre.org))

Example: SSH Brute Force maps to T1110.001 (Brute Force: Password Guessing) under the Credential Access tactic. Adjacent techniques include:
- T1110.003 (Password Spraying) — one password, many accounts
- T1110.004 (Credential Stuffing) — credentials from breach databases
- T1555 (Credentials from Password Stores) — if SSH fails, attacker pivots to reading stored creds

### Tuning a detection rule

Every rule has two knobs:

1. **`trigger_threshold`** — minimum number of query results to create an alert
   - `0` means "any result fires" (good for high-confidence, low-frequency events like root login)
   - Higher values reduce false positives but risk missing slow attacks

2. **`query_frequency` / `query_period`** — how often to run and how far back to look
   - `PT5M` / `PT5M` = run every 5 minutes, look at the last 5 minutes
   - Increasing the period catches slower attacks but increases latency

**Practical tuning workflow:**
1. Run the KQL manually in Log Analytics on 7 days of historical data
2. Count how many results come back — are there benign matches (false positives)?
3. Add exclusion clauses (`| where SyslogMessage !has "<known-benign-pattern>"`) to filter them
4. Set `trigger_threshold` based on the expected benign baseline

### Understanding entity mapping

`entity_mapping` blocks in each rule tell Sentinel which columns in the query output correspond to security entities (Host, IP, Account, etc.). This enables:

- **One-click investigation**: Click the host entity → see its full activity timeline
- **Incident correlation**: Two alerts involving the same IP get automatically linked
- **Enrichment**: Sentinel can enrich entities with threat intel data

---

## Section 6 — What to Explore Next

Once you've completed the core lab, here are high-value extensions in order of complexity:

### Easy (1–2 hours)

- **Add more KQL rules** — browse [MITRE ATT&CK for Linux](https://attack.mitre.org/matrices/enterprise/linux/) and write a rule for any technique that would appear in syslog
- **Tune existing rules** — run each rule's KQL in Log Analytics and check for false positives in your environment
- **Explore the workbook** — open the SOC Detection Dashboard in Sentinel → Workbooks

### Medium (half day)

- **Run the attack simulation** — follow [docs/attack-simulation.md](attack-simulation.md) to trigger real incidents
- **Add Key Vault** — store the SSH key in Azure Key Vault and reference it in Terraform (eliminates the tfvars with sensitive values)
- **Add Azure Policy** — enforce that VMs must have AMA installed, NSGs must exist on subnets, etc.

### Advanced (1–2 days)

- **Add a SOAR playbook** — create an Azure Logic App that auto-closes low-confidence SSH brute force incidents after enrichment
- **Add watchlists** — import a list of known-bad IPs from a threat intel feed and join against it in KQL
- **Add a second VM** — a "management" VM in the management-subnet, and adjust the detection rules to cover lateral movement between it and the workload VM
- **Implement Terraform remote state** — move `terraform.tfstate` to Azure Blob Storage with state locking via Azure Cosmos DB

---

## Quick Reference

### Useful Terraform commands

| Command | What it does |
|---------|-------------|
| `terraform init` | Download providers and modules |
| `terraform plan -out=soc.tfplan` | Preview changes without applying |
| `terraform apply soc.tfplan` | Apply the saved plan |
| `terraform output` | Print all root outputs |
| `terraform state list` | List all resources in state |
| `terraform destroy` | Destroy all resources (confirm carefully) |
| `terraform fmt -recursive` | Auto-format all .tf files |
| `terraform validate` | Check HCL syntax |

### Useful Azure CLI commands

```bash
# Find your subscription ID
az account show --query id -o tsv

# List resource groups
az group list -o table

# Get all resources in the lab resource group
az resource list -g soc-soc-rg -o table

# SSH to the VM via Bastion (requires Azure CLI Bastion extension)
az network bastion ssh \
  --name soc-bastion \
  --resource-group soc-soc-rg \
  --target-resource-id /subscriptions/<sub-id>/resourceGroups/soc-soc-rg/providers/Microsoft.Compute/virtualMachines/soc-workload-vm \
  --auth-type ssh-key \
  --username azureadmin \
  --ssh-key ~/.ssh/azure_soc_key
```

### Useful KQL queries

```kql
-- Check if logs are flowing from the VM
Syslog
| where TimeGenerated >= ago(1h)
| summarize count() by Facility, bin(TimeGenerated, 10m)
| order by TimeGenerated desc

-- See all recent auth events
Syslog
| where Facility in ("auth", "authpriv")
| where TimeGenerated >= ago(1h)
| project TimeGenerated, Computer, SyslogMessage
| order by TimeGenerated desc

-- Check which detection rules have fired
SecurityAlert
| where TimeGenerated >= ago(7d)
| project TimeGenerated, AlertName, AlertSeverity, Description
| order by TimeGenerated desc
```
