# Azure SOC Lab — Infrastructure as Code

![Terraform CI](https://github.com/Josperdo/azure-soc-terraform/actions/workflows/terraform-ci.yml/badge.svg)

Modular Terraform deployment for an Azure-based Security Operations Center (SOC) lab environment. Built as a portfolio project demonstrating cloud security architecture, detection engineering, and DevSecOps practices on Microsoft Azure.

---

## What This Deploys

- **Isolated Virtual Network** — three segmented subnets with least-privilege NSG rules
- **Azure Bastion** — browser-based SSH access with no public IP on any VM
- **Ubuntu 22.04 LTS Workload VM** — hardened target for attack simulation
- **Log Analytics Workspace** — centralized syslog collection and KQL querying
- **Microsoft Sentinel** — cloud-native SIEM with 10 scheduled analytics rules
- **Detection Rules (KQL)** — 10 MITRE ATT&CK-mapped rules covering credential access, privilege escalation, persistence, defense evasion, and execution
- **Data Collection Rule + Azure Monitor Agent** — automated log forwarding from VM to Sentinel using managed identity
- **cloud-init hardening** — auditd + audisp-syslog installed on first boot; kernel audit rules mapped to MITRE ATT&CK techniques
- **Least-privilege RBAC** — VM managed identity scoped to `Monitoring Metrics Publisher` on the workspace only
- **Azure Policy guardrail** — `Allowed locations` built-in policy enforced at resource group scope

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
- **auditd + audisp-syslog** — kernel-level audit rules capture privileged exec, account changes, cron/systemd persistence, and SSH config tampering; events forwarded to Sentinel via `local6` syslog facility
- **Least-privilege RBAC** — VM identity is granted `Monitoring Metrics Publisher` scoped to the workspace only (not subscription-wide)
- **Azure Policy guardrail** — `Allowed locations` built-in policy prevents resources from being created outside the chosen region

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

## Detection Coverage

10 Sentinel scheduled analytics rules deployed via Terraform, each mapped to a MITRE ATT&CK technique and targeting the Linux syslog pipeline.

| # | Rule | Technique | Tactic | Severity |
|---|---|---|---|---|
| 1 | SSH Brute Force | T1110.001 — Brute Force: Password Guessing | Credential Access | Medium |
| 2 | User Added to Sudo Group | T1548.003 — Abuse Elevation Control: Sudo | Privilege Escalation | High |
| 3 | Repeated Failed Sudo Attempts | T1548.003 — Abuse Elevation Control: Sudo | Privilege Escalation | Medium |
| 4 | Cron Job Created by Non-Root User | T1053.003 — Scheduled Task: Cron | Persistence | Medium |
| 5 | New Local User Account Created | T1136.001 — Create Account: Local Account | Persistence | High |
| 6 | Account Password Changed | T1098 — Account Manipulation | Persistence | Medium |
| 7 | New Systemd Service Installed | T1543.002 — Create/Modify System Process: Systemd | Persistence | Medium |
| 8 | Successful Root SSH Login | T1078 — Valid Accounts | Defense Evasion / Initial Access | High |
| 9 | Syslog Daemon Stopped or Restarted | T1070.002 — Indicator Removal: Clear Linux Logs | Defense Evasion | High |
| 10 | Reverse Shell Indicators | T1059.004 — Command and Scripting: Unix Shell | Execution | High |

All rules include entity mapping (Host + IP) so Sentinel automatically links alerts to entity timelines for one-click investigation.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | >= 1.5.0 | [Install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | Latest | [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Azure Subscription | — | **Owner role required** (policy assignment needs Owner) |

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

## Troubleshooting

**`SkuNotAvailable` error during VM creation**

B-series VMs have capacity restrictions in some regions, especially on free trial subscriptions. Set `vm_size = "Standard_D2s_v3"` in your `terraform.tfvars` as a reliable fallback. If `East US` fails, try `location = "East US 2"`.

**Sentinel 409 Conflict on redeploy**

Azure soft-deletes Sentinel alert rule IDs and enforces a cooldown before reusing them. If you destroy and redeploy quickly with the same `prefix`, you will hit this. Either wait 15 minutes before redeploying, or change your `prefix` (e.g. `"lab"` instead of `"soc"`) to generate fresh resource names.

**`terraform apply` fails partway through**

Re-run `terraform plan -out=soc.tfplan && terraform apply soc.tfplan` — Terraform will skip what already exists and only create what failed. Most mid-deploy failures are transient Azure API timing issues that resolve on retry.

---

## Cost Estimate

> **No Azure account yet?** Sign up for an [Azure free account](https://azure.microsoft.com/free/) — new accounts receive **$200 in credit** valid for 30 days. That credit is more than enough to deploy, use, and tear down this lab multiple times without spending a cent.

| Resource | Approximate Monthly Cost |
|---|---|
| Azure Bastion Basic SKU | ~$140 |
| Standard_B2s VM (running 24/7) | ~$30 |
| Public IP (Standard) | ~$4 |
| Log Analytics (30-day retention, minimal ingestion) | ~$2–5 |
| VNet, NSGs, Managed Identity | Free |

Running this lab costs approximately **$5–6/day** if left on 24/7 (Bastion is the dominant cost). For a trial session of a few hours the cost is under $2. The $200 free trial credit covers roughly **30+ days** of continuous use.

> **Tip:** Run `terraform destroy` between lab sessions — re-deploying takes about 10 minutes and saves ~$4.60/day in idle Bastion charges.

---

## Contributing

Pull requests welcome. Useful areas for contribution:

- Additional KQL detection rules mapped to MITRE ATT&CK
- Sentinel workbook for visualising detection coverage
- Terraform remote state configuration (Azure Blob backend)
- Additional attack simulation playbooks

---

## License

MIT — see [LICENSE](LICENSE). Feel free to fork and adapt for your own lab environment.

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
