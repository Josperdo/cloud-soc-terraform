# ─── Local Values ────────────────────────────────────────────────────────────

locals {
  common_tags = merge(
    {
      environment = var.environment
      project     = "azure-soc"
      managed_by  = "terraform"
    },
    var.tags
  )
}

# ─── Resource Group ──────────────────────────────────────────────────────────

module "resource_group" {
  source   = "./modules/resource_group"
  name     = "${var.prefix}-soc-rg"
  location = var.location
  tags     = local.common_tags
}

# ─── Network ─────────────────────────────────────────────────────────────────

module "network" {
  source = "./modules/network"

  prefix                 = var.prefix
  location               = var.location
  resource_group_name    = module.resource_group.name
  vnet_address_space     = var.vnet_address_space
  management_subnet_cidr = var.management_subnet_cidr
  workload_subnet_cidr   = var.workload_subnet_cidr
  bastion_subnet_cidr    = var.bastion_subnet_cidr
  tags                   = local.common_tags
}

# ─── Compute ─────────────────────────────────────────────────────────────────

module "compute" {
  source = "./modules/compute"

  vm_name              = "${var.prefix}-workload-vm"
  location             = var.location
  resource_group_name  = module.resource_group.name
  subnet_id            = module.network.workload_subnet_id
  vm_size              = var.vm_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = local.common_tags
}

# ─── Bastion ─────────────────────────────────────────────────────────────────

module "bastion" {
  source = "./modules/bastion"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = module.resource_group.name
  bastion_subnet_id   = module.network.bastion_subnet_id
  tags                = local.common_tags
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = module.resource_group.name
  vm_id               = module.compute.vm_id
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}
