# Azure SOC Lab — Infrastructure as Code

![Terraform CI](https://github.com/Josperdo/azure-soc-terraform/actions/workflows/terraform-ci.yml/badge.svg)

Modular Terraform deployment for an Azure-based Security Operations Center (SOC) lab environment. Built as a portfolio project demonstrating cloud security architecture, detection engineering, and DevSecOps practices on Microsoft Azure.

## Project Status

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | Secure cloud infrastructure — network, compute, Bastion, monitoring pipeline | Complete |
| **Phase 2** | Detection engineering — KQL analytics rules + attack simulation + evidence | In Progress |
| **Phase 3** | DevSecOps — CI/CD pipeline with automated IaC validation and security scanning | Complete |

---

## What This Deploys

- **Isolated Virtual Network** — three segmented subnets with least-privilege NSG rules
- **Azure Bastion** — browser-based SSH access with no public IP on any VM
- **Ubuntu 22.04 LTS Workload VM** — hardened target for attack simulation
- **Log Analytics Workspace** — centralized syslog collection and KQL querying
- **Microsoft Sentinel** — cloud-native SIEM with 10 scheduled analytics rules
- **Detection Rules (KQL)** — 10 MITRE ATT&CK-mapped rules covering credential access, privilege escalation, persistence, defense evasion, and execution
- **Data Collection Rule + Azure Monitor Agent** — automated log forwarding from VM to Sentinel using managed identity

---

## Architecture Overview

```
Internet
   │
   │ HTTPS (443) only
   ▼
┌───────────────────────────────────────────────────────┐
│                  Azure Virtual Network                │
│                  10.0.0.0/16                          │
│                                                       │
│  ┌─────────────────────┐   ┌──────────────────────┐   │
│  │  AzureBastionSubnet │   │  management-subnet   │   │
│  │  10.0.3.0/26        │   │  10.0.1.0/24         │   │
│  │                     │   │                      │   │
│  │  [Azure Bastion]────┼───┼──► SSH (port 22)     │   │
│  └─────────────────────┘   └──────────────────────┘   │
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
                              ┌──────────▼────────────────┐
                              │  Log Analytics Workspace  │
                              │  + Microsoft Sentinel     │
                              └───────────────────────────┘
```

### Resources Deployed

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all lab resources |
| Virtual Network | Isolated network with three segmented subnets |
| NSGs (x3) | Least-privilege inbound/outbound rules per subnet |
| Azure Bastion | Secure browser-based SSH — no public VM IP |
| Ubuntu 22.04 LTS VM | Workload target for attack simulation |
| System-Assigned Identity | Passwordless Azure authentication for the VM |
| Boot Diagnostics | Serial console access and startup logging |
| Log Analytics Workspace | Centralized log collection and querying |
| Microsoft Sentinel | SIEM/SOAR platform with 10 active detection rules |
| Data Collection Rule | Routes Linux syslog from VM to the workspace |
| Azure Monitor Agent | Ships logs using managed identity — no stored credentials |
| Sentinel Analytics Rules (x10) | MITRE ATT&CK-mapped KQL scheduled query rules |

### Security Controls

- **No public IP on any VM** — access exclusively via Azure Bastion
- **No inbound SSH from the internet** — NSGs explicitly deny `Internet` source
- **Subnet segmentation** — management and workload subnets have separate NSGs
- **Managed identity on VM** — eliminates stored credentials for Azure API access
- **SSH key-only authentication** — password authentication disabled on the VM

---

## Use Case

This lab is designed for security practitioners who want to:

- Practice detection engineering against a realistic Azure target environment
- Learn how Azure Monitor, Log Analytics, and Sentinel fit together end-to-end
- Build and validate KQL detection rules mapped to MITRE ATT&CK
- Demonstrate cloud security skills with a deployable, documented portfolio project

---

## What You'll Learn

| Skill | How It's Demonstrated |
|---|---|
| Infrastructure as Code | Modular Terraform, azurerm provider ~4.0, reusable child modules |
| Cloud Security Architecture | Bastion, NSGs, no public IPs, managed identity, subnet segmentation |
| Detection Engineering | 10 KQL rules across 5 MITRE tactics, validated against real syslog data |
| DevSecOps | GitHub Actions CI — `fmt`, `validate`, tfsec, and checkov on every PR |

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | >= 1.5.0 | [Install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | Latest | [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Azure Subscription | — | Contributor or Owner role required |

The following Azure resource providers must be registered (Terraform will attempt this automatically):

```
Microsoft.Compute / Microsoft.Network / Microsoft.OperationalInsights / Microsoft.SecurityInsights / Microsoft.Insights
```

Register manually if needed:

```bash
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.Insights
```

---

## Quick Start

**1. Authenticate**

```bash
az login
az account set --subscription "<your-subscription-id>"
```

**2. Generate an SSH key pair**

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_soc_key
```

**3. Configure variables**

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `subscription_id` — run `az account show --query id -o tsv`
- `admin_ssh_public_key` — contents of `~/.ssh/azure_soc_key.pub`

**4. Deploy**

```bash
terraform init
terraform plan -out=soc.tfplan
terraform apply soc.tfplan
```

Deployment takes approximately **8–12 minutes** (Bastion provisioning is the longest step). Expect **~30 resources** created.

**5. Connect to the VM**

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to your resource group → VM → **Connect → Bastion**
3. Enter the admin username (default: `azureadmin`) and your SSH private key

**6. Tear down**

```bash
terraform destroy
```

---

## Key Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Resource group containing all lab resources |
| `vm_private_ip` | Private IP of the workload VM |
| `vm_principal_id` | Object ID of the VM's managed identity |
| `bastion_name` | Name of the Azure Bastion host |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace |
| `sentinel_workspace_id` | Workspace where Sentinel is enabled |

---

## Cost Estimate

| Resource | Approximate Monthly Cost |
|---|---|
| Azure Bastion Basic SKU | ~$140 |
| Standard_B2s VM (running 24/7) | ~$30 |
| Public IP (Standard) | ~$4 |
| Log Analytics (30-day retention, minimal ingestion) | ~$2–5 |
| VNet, NSGs, Managed Identity | Free |

> **Tip:** Bastion is the dominant cost at ~$0.19/hr. Destroy the environment between lab sessions with `terraform destroy` to avoid idle charges.

---

## Contributing

Pull requests welcome. Useful areas for contribution:

- Additional KQL detection rules mapped to MITRE ATT&CK
- Sentinel workbook for visualising detection coverage
- Terraform remote state configuration (Azure Blob backend)
- Additional attack simulation playbooks

---

## References

- [Microsoft Sentinel Documentation](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Azure Bastion NSG Requirements](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [Azure Monitor Agent Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [tfsec — Terraform Security Scanner](https://github.com/aquasecurity/tfsec)
- [checkov — IaC Security Scanner](https://github.com/bridgecrewio/checkov)
