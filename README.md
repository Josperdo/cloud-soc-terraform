# Multi-Cloud SOC Lab — Infrastructure as Code

![Terraform CI](https://github.com/Josperdo/azure-soc-terraform/actions/workflows/terraform-ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/Josperdo/azure-soc-terraform/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Josperdo/azure-soc-terraform)](https://github.com/Josperdo/azure-soc-terraform/commits/main)

Modular Terraform deployment for a multi-cloud Security Operations Center (SOC) lab environment spanning **Azure** and **AWS**. Demonstrates cloud security architecture, detection engineering, and DevSecOps practices across both major cloud platforms.

```bash
make deploy target=azure
make deploy target=aws
```

---

## What This Deploys

### Azure Stack

- **Virtual Network** — three segmented subnets with least-privilege NSG rules
- **Azure Bastion** — browser-based SSH with no public IP on any VM
- **Ubuntu 22.04 LTS VM** — hardened target for attack simulation
- **Log Analytics Workspace** — centralized syslog collection and KQL querying
- **Microsoft Sentinel** — cloud-native SIEM with 10 scheduled analytics rules mapped to MITRE ATT&CK
- **Data Collection Rule + Azure Monitor Agent** — automated log forwarding via managed identity
- **cloud-init hardening** — auditd + audisp-syslog with kernel audit rules on first boot
- **Least-privilege RBAC** — VM managed identity scoped to `Monitoring Metrics Publisher` only
- **Azure Policy guardrail** — `Allowed locations` enforced at resource group scope

### AWS Stack

- **VPC + Subnets** — management and isolated workload subnets with Security Groups and NACLs
- **SSM Session Manager** — shell access with zero open inbound ports
- **Ubuntu 22.04 LTS EC2** — hardened target with IMDSv2 enforced, encrypted EBS, IAM Instance Profile
- **CloudTrail** — account-level API logging to CloudWatch Logs + S3
- **CloudWatch Log Groups** — `/soc-lab/syslog`, `/soc-lab/auth`, `/soc-lab/ssm-sessions`, `/soc-lab/cloudtrail`
- **CloudWatch Dashboard** — SOC visibility panel for auth events, syslog, SSM sessions, and API activity
- **GuardDuty** *(optional — 30-day trial)* — threat detection across CloudTrail, VPC Flow Logs, and DNS
- **Security Hub** *(optional — 30-day trial)* — aggregated findings with AWS Foundational Security Best Practices
- **cloud-init hardening** — same auditd ruleset as Azure; CloudWatch Agent ships logs on first boot

---

## Architecture

### Azure

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
│                             │  [Ubuntu 22.04 LTS]  │  │
│                             └──────────┬───────────┘  │
└────────────────────────────────────────┼──────────────┘
                                         │ Syslog (DCR + AMA)
                              ┌──────────▼────────────────┐
                              │  Log Analytics Workspace  │
                              │  + Microsoft Sentinel     │
                              └───────────────────────────┘
```

### AWS

```
Internet
   │
   │ Outbound 443 only (SSM agent)
   ▼
┌───────────────────────────────────────────────────────┐
│                       VPC                             │
│                  10.0.0.0/16                          │
│                                                       │
│  ┌──────────────────────────────────────────────────┐ │
│  │  management-subnet  10.0.1.0/24                  │ │
│  │  [Ubuntu 22.04 LTS EC2]                          │ │
│  │  - IAM Instance Profile (SSM + CloudWatch)       │ │
│  │  - IMDSv2 enforced                               │ │
│  │  - Encrypted EBS                                 │ │
│  └──────────────────┬───────────────────────────────┘ │
│                     │                                 │
│  ┌──────────────────▼───────────────────────────────┐ │
│  │  workload-subnet  10.0.2.0/24  (isolated)        │ │
│  └──────────────────────────────────────────────────┘ │
└─────────────────────┬─────────────────────────────────┘
                      │ CloudWatch Agent + CloudTrail
         ┌────────────▼──────────────────────┐
         │  CloudWatch Log Groups            │
         │  /soc-lab/syslog                  │
         │  /soc-lab/auth                    │
         │  /soc-lab/ssm-sessions            │
         │  /soc-lab/cloudtrail              │
         └────────────┬──────────────────────┘
                      │ findings
         ┌────────────▼──────────────────────┐
         │  GuardDuty + Security Hub         │
         │  (optional — 30-day trial)        │
         └───────────────────────────────────┘
```

---

## Azure vs AWS — Service Mapping

| Concept | Azure | AWS |
|---|---|---|
| Networking | VNet + Subnets + NSGs | VPC + Subnets + Security Groups + NACLs |
| Secure shell access | Azure Bastion (dedicated host) | SSM Session Manager (no host) |
| VM identity | System-assigned Managed Identity | IAM Instance Profile |
| Log collection | Azure Monitor Agent + DCR | CloudWatch Agent |
| Log storage | Log Analytics Workspace | CloudWatch Log Groups |
| SIEM / threat detection | Microsoft Sentinel | GuardDuty + Security Hub |
| API activity logging | Azure Activity Log + Diagnostic Settings | CloudTrail |
| Guardrails | Azure Policy | AWS Config / Security Hub standards |
| CI/CD scanning | tfsec + checkov | tfsec + checkov |

---

## Detection Coverage (Azure)

10 Sentinel scheduled analytics rules deployed via Terraform, each mapped to a MITRE ATT&CK technique.

| # | Rule | Technique | Tactic | Severity |
|---|---|---|---|---|
| 1 | SSH Brute Force | T1110.001 | Credential Access | Medium |
| 2 | User Added to Sudo Group | T1548.003 | Privilege Escalation | High |
| 3 | Repeated Failed Sudo Attempts | T1548.003 | Privilege Escalation | Medium |
| 4 | Cron Job Created by Non-Root User | T1053.003 | Persistence | Medium |
| 5 | New Local User Account Created | T1136.001 | Persistence | High |
| 6 | Account Password Changed | T1098 | Persistence | Medium |
| 7 | New Systemd Service Installed | T1543.002 | Persistence | Medium |
| 8 | Successful Root SSH Login | T1078 | Defense Evasion | High |
| 9 | Syslog Daemon Stopped or Restarted | T1070.002 | Defense Evasion | High |
| 10 | Reverse Shell Indicators | T1059.004 | Execution | High |

---

## Prerequisites

### Azure

| Tool | Notes |
|---|---|
| Terraform >= 1.5.0 | [Install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Azure Subscription | Owner role required (policy assignment needs Owner) |

### AWS

| Tool | Notes |
|---|---|
| Terraform >= 1.5.0 | Same installation as above |
| AWS CLI v2 | [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| AWS Account | Free Tier covers all lab resources for 12 months |
| IAM User | Non-root IAM user with `AdministratorAccess` — never use root for CLI |

### Makefile (optional but recommended)

```bash
winget install GnuWin32.Make   # Windows
brew install make              # macOS
sudo apt install make          # Linux
```

---

## Quick Start

### Azure

```bash
# 1. Authenticate
az login
az account set --subscription "<your-subscription-id>"

# 2. Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_soc_key

# 3. Configure variables
cd environments/azure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set subscription_id and admin_ssh_public_key

# 4. Deploy
make deploy target=azure

# 5. Connect — Azure Portal → Resource Group → VM → Connect → Bastion

# 6. Tear down
make destroy target=azure
```

### AWS

```bash
# 1. Authenticate
aws configure
aws sts get-caller-identity  # verify

# 2. Generate SSH key (or reuse your Azure key)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws_soc_key

# 3. Configure variables
cd environments/aws
cp terraform.tfvars.example terraform.tfvars
# Set enable_threat_detection = true once your account is fully activated

# 4. Deploy
make deploy target=aws

# 5. Connect via SSM (no open ports required)
aws ssm start-session --target <instance-id> --region us-east-1

# 6. Tear down — run before day 30 if GuardDuty/Security Hub are enabled
make destroy target=aws
```

---

## Key Outputs

### Azure

| Output | Description |
|---|---|
| `resource_group_name` | Resource group containing all lab resources |
| `vm_private_ip` | Private IP of the workload VM |
| `log_analytics_workspace_id` | Resource ID of the Log Analytics workspace |
| `sentinel_workspace_id` | Workspace where Sentinel is enabled |

### AWS

| Output | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `ssm_connect_command` | Exact CLI command to start an SSM session |
| `soc_dashboard_url` | Direct link to the CloudWatch SOC dashboard |
| `cloudtrail_arn` | ARN of the CloudTrail trail |
| `guardduty_detector_id` | GuardDuty detector ID (empty if threat detection disabled) |

---

## Cost Estimate

### Azure

| Resource | Approximate Monthly Cost |
|---|---|
| Azure Bastion Basic SKU | ~$140 |
| Standard_B2s VM (running 24/7) | ~$30 |
| Public IP (Standard) | ~$4 |
| Log Analytics (30-day retention) | ~$2–5 |
| VNet, NSGs, Managed Identity | Free |

> Running costs approximately **$5–6/day**. The $200 Azure free trial credit covers ~30+ days of continuous use. Run `terraform destroy` between sessions to avoid idle Bastion charges.

### AWS

| Resource | Free Tier | Cost after free tier |
|---|---|---|
| EC2 t3.micro | 750 hrs/month (12 months) | ~$8/month |
| GuardDuty | 30-day trial | Per GB analyzed |
| Security Hub | 30-day trial | Per finding |
| CloudTrail (mgmt events) | Free | Free |
| CloudWatch Logs | 5 GB/month | ~$0.50/GB |
| SSM Session Manager | Always free | Free |

> AWS lab costs are **near zero** within Free Tier limits. Set a $5/month billing alert in AWS Budgets and run `terraform destroy` after each session. If using GuardDuty or Security Hub, destroy before day 30 on new accounts.

---

## Troubleshooting

**Azure: `SkuNotAvailable` error during VM creation**

B-series VMs have capacity restrictions in some regions. Set `vm_size = "Standard_D2s_v3"` in `terraform.tfvars`. If `East US` fails, try `location = "East US 2"`.

**Azure: Sentinel 409 Conflict on redeploy**

Azure soft-deletes Sentinel alert rule IDs with a cooldown before reuse. Wait 15 minutes before redeploying, or change your `prefix` to generate fresh resource names.

**AWS: `SubscriptionRequiredException` for GuardDuty or Security Hub**

Your account isn't fully activated yet. Credit card verification can take up to 24 hours on new accounts. Deploy with `enable_threat_detection = false` (the default) and set it to `true` once activated.

**AWS: `TargetNotConnected` when running SSM start-session**

The SSM agent installs via cloud-init on first boot — wait 3–4 minutes after `terraform apply` completes. Confirm EC2 Status Checks shows 2/2 passed before connecting.

**General: `terraform apply` fails partway through**

Re-run `terraform apply` — Terraform skips what already exists and only retries what failed. Most mid-deploy failures are transient API timing issues that resolve on retry.

---

## Repository Structure

```
multi-cloud-soc-terraform/
  environments/
    azure/          # Azure root module — providers, variables, main, outputs
    aws/            # AWS root module — providers, variables, main, outputs
  modules/
    azure/          # Azure child modules
      resource_group/
      network/
      compute/
      bastion/
      monitoring/
    aws/            # AWS child modules
      network/
      compute/
      bastion/      # SSM Session Manager config
      monitoring/   # GuardDuty, Security Hub, CloudTrail, CloudWatch
  Makefile          # make deploy target=azure|aws
  .github/
    workflows/
      terraform-ci.yml   # Validates + scans both clouds on every PR
```

---

## Contributing

Pull requests welcome. Useful areas for contribution:

- Additional KQL detection rules mapped to MITRE ATT&CK
- AWS CloudWatch metric alarms for GuardDuty finding severity
- Terraform remote state configuration (Azure Blob / S3 backend)
- Additional attack simulation playbooks

---

## License

MIT — see [LICENSE](LICENSE). Feel free to fork and adapt for your own lab environment.

---

## References

**Azure**
- [Microsoft Sentinel Documentation](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Azure Bastion NSG Requirements](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [Azure Monitor Agent Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

**AWS**
- [SSM Session Manager Setup](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started.html)
- [GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html)
- [Security Hub Documentation](https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

**General**
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [tfsec — Terraform Security Scanner](https://github.com/aquasecurity/tfsec)
- [checkov — IaC Security Scanner](https://github.com/bridgecrewio/checkov)
