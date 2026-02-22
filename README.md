# Azure SOC Terraform

A cloud-native Security Operations Center (SOC) built on Microsoft Azure using Terraform. Designed as a cybersecurity portfolio project demonstrating real-world cloud security architecture, detection engineering, and DevSecOps practices.

## Project Status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Secure cloud infrastructure (IaC foundation) | Complete |
| **Phase 2** | Detection engineering — KQL rules + attack simulation | Planned |
| **Phase 3** | CI/CD pipeline — automated IaC validation + security scanning | Planned |

---

## Architecture Overview

```
Internet
   │
   │ HTTPS (443) only
   ▼
┌──────────────────────────────────────────────────────┐
│                  Azure Virtual Network                │
│                  10.0.0.0/16                          │
│                                                       │
│  ┌─────────────────────┐   ┌──────────────────────┐  │
│  │  AzureBastionSubnet │   │  management-subnet   │  │
│  │  10.0.3.0/26        │   │  10.0.1.0/24         │  │
│  │                     │   │                      │  │
│  │  [Azure Bastion]────┼───┼──► SSH (port 22)     │  │
│  └─────────────────────┘   └──────────────────────┘  │
│                                      │                │
│                             ┌────────▼─────────────┐  │
│                             │  workload-subnet     │  │
│                             │  10.0.2.0/24         │  │
│                             │                      │  │
│                             │  [Ubuntu 22.04 LTS]  │  │
│                             │  - System Identity   │  │
│                             │  - Boot Diagnostics  │  │
│                             │  - AMA Extension     │  │
│                             └──────────┬───────────┘  │
└────────────────────────────────────────┼──────────────┘
                                         │ Syslog (DCR)
                              ┌──────────▼───────────────┐
                              │  Log Analytics Workspace  │
                              │  + Microsoft Sentinel     │
                              └───────────────────────────┘
```

### What's Deployed

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all lab resources |
| Virtual Network | Isolated network with three segmented subnets |
| NSGs (x3) | Least-privilege inbound/outbound rules per subnet |
| Azure Bastion | Secure browser-based SSH access — no public VM IP |
| Ubuntu 22.04 LTS VM | Workload target for future attack simulation |
| System-Assigned Identity | Passwordless Azure authentication for the VM |
| Boot Diagnostics | Serial console access and startup logging |
| Log Analytics Workspace | Centralized log collection and querying |
| Microsoft Sentinel | SIEM/SOAR platform (analytics configured in Phase 2) |
| Data Collection Rule | Routes Linux syslog from VM to the workspace |
| Azure Monitor Agent | Installed on VM; uses managed identity to ship logs |

### Security Controls

- **No public IP on any VM** — access exclusively via Azure Bastion
- **No inbound SSH from the internet** — NSGs explicitly deny `Internet` → workload/management subnets
- **Subnet segmentation** — management and workload subnets have separate NSGs
- **Azure Bastion NSG** — implements all Microsoft-required rules for Bastion to function
- **Managed identity on VM** — eliminates stored credentials for Azure API access
- **SSH key-only authentication** — password authentication disabled on the VM

---

## Project Structure

```
azure-soc-terraform/
├── main.tf                      # Root module — wires all child modules together
├── variables.tf                 # Root input variables
├── outputs.tf                   # Root outputs
├── providers.tf                 # Terraform and AzureRM provider configuration
├── terraform.tfvars.example     # Example variable values (copy → terraform.tfvars)
├── .gitignore
├── README.md
└── modules/
    ├── resource_group/
    │   ├── main.tf              # azurerm_resource_group
    │   ├── variables.tf
    │   └── outputs.tf
    ├── network/
    │   ├── main.tf              # VNet, 3 subnets, 3 NSGs + associations
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/
    │   ├── main.tf              # NIC, Linux VM, managed identity, boot diagnostics
    │   ├── variables.tf
    │   └── outputs.tf
    ├── bastion/
    │   ├── main.tf              # Public IP (Standard), Azure Bastion host
    │   ├── variables.tf
    │   └── outputs.tf
    └── monitoring/
        ├── main.tf              # Log Analytics Workspace, Sentinel, AMA, DCR + association
        ├── variables.tf
        └── outputs.tf
```

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | >= 1.5.0 | [Install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | Latest | [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Azure Subscription | — | Contributor or Owner role required |

### Required Azure Resource Providers

The following providers must be registered on your subscription (Terraform will attempt this automatically if your account has permission):

```
Microsoft.Compute
Microsoft.Network
Microsoft.OperationalInsights
Microsoft.SecurityInsights
Microsoft.Insights
```

Register manually if needed:

```bash
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.Insights
```

---

## Deployment

### 1. Authenticate to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Generate an SSH Key Pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_soc_key
```

Keep `azure_soc_key` (private key) secure. You will paste the contents of `azure_soc_key.pub` into your `terraform.tfvars`.

### 3. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at minimum:

- `subscription_id` — your Azure Subscription ID (`az account show --query id -o tsv`)
- `admin_ssh_public_key` — contents of `~/.ssh/azure_soc_key.pub`

### 4. Initialize Terraform

```bash
terraform init
```

This downloads the AzureRM provider (~4.0) and sets up the module cache.

### 5. Review the Plan

```bash
terraform plan -out=soc.tfplan
```

Review the output carefully. Expect approximately **18-20 resources** to be created.

### 6. Apply

```bash
terraform apply soc.tfplan
```

Deployment takes approximately **8-12 minutes** (Azure Bastion provisioning is the longest step).

### 7. Connect to the VM

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to your resource group → the VM → **Connect → Bastion**
3. Enter the admin username (default: `azureadmin`) and your SSH private key
4. Click **Connect**

---

## Key Outputs

After `terraform apply`, the following values are printed:

| Output | Description |
|---|---|
| `resource_group_name` | Resource group containing all lab resources |
| `vm_private_ip` | Private IP of the workload VM |
| `vm_principal_id` | Object ID of the VM's managed identity (for RBAC assignments) |
| `bastion_name` | Name of the Azure Bastion host |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace |
| `sentinel_workspace_id` | Same workspace where Sentinel is enabled |

---

## Cost Estimate

| Resource | Approximate Cost |
|---|---|
| Standard_B2s VM (running 24/7) | ~$30/month |
| Azure Bastion Basic SKU | ~$140/month |
| Log Analytics (30-day retention, minimal ingestion) | ~$2–5/month |
| Public IP (Standard) | ~$4/month |
| VNet, NSGs, Managed Identity | Free |

> **Tip:** Stop the VM when not in use to avoid compute charges. The Bastion host is the largest recurring cost — consider destroying the entire environment with `terraform destroy` between lab sessions.

---

## Cleanup

```bash
terraform destroy
```

This removes all resources in the correct dependency order.

---

## Phase 2 — Detection Engineering

> Goal: Prove the monitoring pipeline works by writing real detection rules, triggering them with simulated attacks, and capturing evidence in Sentinel.

### Deliverables

**2a. Sentinel Scheduled Query Rules (KQL)**

Three Terraform-managed detection rules targeting realistic Linux attack patterns:

| Rule | MITRE Technique | What It Detects |
|---|---|---|
| SSH Brute Force | T1110.001 — Brute Force | 5+ failed SSH auth attempts from the same source IP within 5 minutes |
| Privilege Escalation via Sudo | T1548.003 — Sudo | A user added to the `sudo` or `wheel` group |
| Persistence via Cron | T1053.003 — Cron Job | New cron entry written by a non-root user |

**2b. Attack Simulation**

Using [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) on the workload VM to fire each technique above and confirm Sentinel generates an incident.

**2c. Evidence**

Screenshots added to `docs/screenshots/` showing:
- Sentinel incident panel with alerts firing
- KQL query results in Log Analytics
- The simulated attack command that triggered each alert

**2d. Sentinel Workbook**

A single Terraform-managed workbook with three tiles:
- Failed login attempts (last 24 hours)
- Sudo group modification events
- Cron job creation events

### What This Phase Does NOT Include

Keeping scope tight — the following are intentionally deferred or excluded:

- ML-based analytics (requires weeks of baseline data)
- Threat intelligence / watchlists (Phase 2+ stretch goal)
- Key Vault (good addition but not core to detection engineering)
- Azure Policy (operational hardening, not detection)

---

## Phase 3 — CI/CD Pipeline (Project Complete)

> Goal: Show the code is maintained like a real team project — automated checks run on every pull request so no broken or insecure Terraform ever merges.

### Deliverables

**3a. GitHub Actions Workflow** (`.github/workflows/terraform-ci.yml`)

Triggered on every pull request to `main`:

| Step | Tool | What It Checks |
|---|---|---|
| Format | `terraform fmt -check` | Code is consistently formatted |
| Validate | `terraform validate` | HCL syntax is valid |
| Security scan | `tfsec` or `checkov` | No high/critical IaC misconfigurations |

**3b. README Badge**

A GitHub Actions status badge at the top of the README so visitors can see the pipeline is green.

**3c. Final Documentation Pass**

- Architecture diagram image (`docs/architecture.png`) replacing the ASCII diagram
- A "How to contribute / fork this for your own lab" section
- Confirmed working deployment instructions with real output screenshots

### Why This Is the Finish Line

After Phase 3, the project demonstrates:

| Skill | Evidence |
|---|---|
| Infrastructure as Code | Modular Terraform, azurerm provider, state management |
| Cloud Security Architecture | Bastion, NSGs, no public IPs, managed identity |
| Detection Engineering | KQL rules mapped to MITRE ATT&CK, proven with simulation |
| DevSecOps | CI/CD pipeline with automated IaC security scanning |

That combination covers what cloud security, SOC engineer, and detection engineer job descriptions actually ask for.

---

## References

- [Azure Bastion NSG Requirements](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [Microsoft Sentinel Documentation](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Azure Monitor Agent Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [tfsec — Terraform Security Scanner](https://github.com/aquasecurity/tfsec)
- [checkov — IaC Security Scanner](https://github.com/bridgecrewio/checkov)
