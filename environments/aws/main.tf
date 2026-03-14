# ─── Local Values ────────────────────────────────────────────────────────────

locals {
  common_tags = merge(
    {
      environment = var.environment
      project     = "multi-cloud-soc"
      managed_by  = "terraform"
    },
    var.tags
  )
}

# ─── Module Dependency Order ─────────────────────────────────────────────────
# network    → required first (subnets + SGs consumed by compute)
# monitoring → before bastion (creates the SSM sessions log group bastion references)
# compute    → after network (needs subnet_id and security_group_id)
# bastion    → after monitoring (needs ssm_sessions_log_group_name output)

# ─── Network ─────────────────────────────────────────────────────────────────

module "network" {
  source = "../../modules/aws/network"

  prefix                 = var.prefix
  region                 = var.region
  vpc_cidr               = var.vpc_cidr
  management_subnet_cidr = var.management_subnet_cidr
  workload_subnet_cidr   = var.workload_subnet_cidr
  tags                   = local.common_tags
}

# ─── Monitoring ──────────────────────────────────────────────────────────────
# Deployed before bastion — bastion needs the SSM sessions log group name.

module "monitoring" {
  source = "../../modules/aws/monitoring"

  prefix                  = var.prefix
  region                  = var.region
  log_retention_days      = var.log_retention_days
  enable_threat_detection = var.enable_threat_detection
  tags                    = local.common_tags
}

# ─── Compute ─────────────────────────────────────────────────────────────────

module "compute" {
  source = "../../modules/aws/compute"

  instance_name        = "${var.prefix}-workload-vm"
  subnet_id            = module.network.management_subnet_id
  security_group_id    = module.network.management_sg_id
  instance_type        = var.instance_type
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = local.common_tags
}

# ─── Bastion (SSM Session Manager) ───────────────────────────────────────────
# Configures account-wide Session Manager preferences.
# No EC2 bastion host — SSM provides shell access without opening any ports.

module "bastion" {
  source = "../../modules/aws/bastion"

  cloudwatch_log_group_name = module.monitoring.ssm_sessions_log_group_name
  tags                      = local.common_tags
}
