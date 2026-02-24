# Azure SOC Lab — Infrastructure as Code

![Terraform CI](https://github.com/Josperdo/azure-soc-terraform/actions/workflows/terraform-ci.yml/badge.svg)

Modular Terraform deployment for an Azure-based Security Operations Center (SOC) lab environment. Built as a portfolio project demonstrating cloud security architecture, detection engineering, and DevSecOps practices on Microsoft Azure.

<<<<<<< HEAD
## What This Deploys

- **Isolated Virtual Network** — three segmented subnets with least-privilege NSG rules
- **Azure Bastion** — browser-based SSH access with no public IP on any VM
- **Ubuntu 22.04 LTS Workload VM** — hardened target for attack simulation
- **Log Analytics Workspace** — centralized syslog collection and KQL querying
- **Microsoft Sentinel** — cloud-native SIEM with three scheduled analytics rules
- **Detection Rules (KQL)** — SSH brute force, privilege escalation, and cron persistence mapped to MITRE ATT&CK
- **Data Collection Rule + Azure Monitor Agent** — automated log forwarding from VM to Sentinel using managed identity

---

=======
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679
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
<<<<<<< HEAD
| Azure Bastion | Secure browser-based SSH — no public VM IP |
=======
| Azure Bastion | Secure browser-based SSH access — no public VM IP |
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679
| Ubuntu 22.04 LTS VM | Workload target for attack simulation |
| System-Assigned Identity | Passwordless Azure authentication for the VM |
| Boot Diagnostics | Serial console access and startup logging |
| Log Analytics Workspace | Centralized log collection and querying |
<<<<<<< HEAD
| Microsoft Sentinel | SIEM/SOAR platform with scheduled analytics rules |
| Data Collection Rule | Routes Linux syslog from VM to the workspace |
| Azure Monitor Agent | Ships logs using managed identity — no stored credentials |
=======
| Microsoft Sentinel | SIEM/SOAR platform with 10 active detection rules |
| Data Collection Rule | Routes Linux syslog from VM to the workspace |
| Azure Monitor Agent | Installed on VM; uses managed identity to ship logs |
| Sentinel Analytics Rules (x10) | MITRE ATT&CK-mapped KQL detection rules |
| SOC Detection Dashboard | Azure Monitor Workbook with 3 KQL query tiles |
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679

### Security Controls

- **No public IP on any VM** — access exclusively via Azure Bastion
- **No inbound SSH from the internet** — NSGs explicitly deny `Internet` source
- **Subnet segmentation** — management and workload subnets have separate NSGs
- **Managed identity on VM** — eliminates stored credentials for Azure API access
- **SSH key-only authentication** — password authentication disabled on the VM

---

## Use Case

<<<<<<< HEAD
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
| Detection Engineering | KQL rules for T1110 / T1548 / T1053, validated against real syslog data |
| DevSecOps | GitHub Actions CI — `fmt`, `validate`, tfsec, and checkov on every PR |
=======
```
azure-soc-terraform/
├── main.tf                      # Root module — wires all child modules together
├── variables.tf                 # Root input variables
├── outputs.tf                   # Root outputs
├── providers.tf                 # Terraform and AzureRM provider configuration
├── terraform.tfvars.example     # Example variable values (copy → terraform.tfvars)
├── .gitignore
├── README.md
├── docs/
│   ├── lab-guide.md             # Step-by-step learning guide with architecture deep-dives
│   ├── attack-simulation.md     # Exact commands to trigger each detection rule
│   ├── kql-reference.md         # All 10 KQL rules explained with tuning guidance
│   └── troubleshooting.md       # Common deployment and monitoring issues
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
        ├── analytics_rules.tf   # 10 Sentinel Scheduled Query Rules (MITRE ATT&CK mapped)
        ├── workbook.tf          # SOC Detection Dashboard workbook
        ├── variables.tf
        └── outputs.tf
```
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679

---

## Learning Guide

New to this lab? Start here:

| Document | What it covers |
|----------|---------------|
| [docs/lab-guide.md](docs/lab-guide.md) | Full walkthrough — architecture decisions, Terraform module deep-dive, monitoring pipeline, detection engineering 101, and what to explore next |
| [docs/attack-simulation.md](docs/attack-simulation.md) | Exact bash commands to trigger each of the 10 detection rules and verify incidents in Sentinel |
| [docs/kql-reference.md](docs/kql-reference.md) | Every KQL query explained — which fields it uses, how to tune it, and known false positives |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common deployment, monitoring, and Sentinel issues with root causes and fixes |

---

## Fork This Repo

1. Click **Fork** on GitHub → clone your fork locally
2. Copy the example vars file: `cp terraform.tfvars.example terraform.tfvars`
3. Set at minimum: `subscription_id` and `admin_ssh_public_key`
4. Optionally change `prefix` (2–6 lowercase characters) so your resource names don't conflict with anyone else's
5. Run `terraform init && terraform plan` to preview, then `terraform apply` to deploy

**Cost tip:** Azure Bastion is the largest cost (~$140/month). Run `terraform destroy` between sessions — re-deploying takes about 10 minutes.

See [docs/lab-guide.md](docs/lab-guide.md) for a full walkthrough including what's safe to customize and what to leave alone.

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
<<<<<<< HEAD
=======
```

Review the output carefully. Expect approximately **33 resources** to be created.

### 6. Apply

```bash
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679
terraform apply soc.tfplan
```

Deployment takes approximately **8–12 minutes** (Bastion provisioning is the longest step). Expect **~20 resources** created.

**5. Connect to the VM**

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to your resource group → VM → **Connect → Bastion**
3. Enter the admin username (default: `azureadmin`) and your SSH private key

**6. Tear down**

```bash
terraform destroy
```

---

<<<<<<< HEAD
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

=======
>>>>>>> 4cc058b69282209f5b674d674c633d8bf1235679
## References

- [Microsoft Sentinel Documentation](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Azure Bastion NSG Requirements](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [Azure Monitor Agent Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [tfsec — Terraform Security Scanner](https://github.com/aquasecurity/tfsec)
- [checkov — IaC Security Scanner](https://github.com/bridgecrewio/checkov)
