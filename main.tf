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

# ─── RBAC — VM → Log Analytics (Monitoring Metrics Publisher) ────────────────
# Grants the VM's system-assigned managed identity the minimum permissions
# needed to publish metrics to the Log Analytics workspace without any stored
# credentials.  Role is scoped to the workspace, not the subscription.

resource "azurerm_role_assignment" "vm_metrics_publisher" {
  scope                = module.monitoring.workspace_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = module.compute.principal_id
}

# ─── Azure Policy — Restrict allowed deployment regions ──────────────────────
# Prevents resources from being accidentally created outside the chosen region.
# Uses the Azure built-in "Allowed locations" policy so no custom policy
# definition is needed — works in any subscription with no extra permissions
# beyond Owner on the resource group.

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "${var.prefix}-allowed-locations"
  resource_group_id    = module.resource_group.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  display_name         = "SOC Lab — Allowed Locations"
  description          = "Restricts resource creation to the region chosen at deploy time."

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [var.location]
    }
  })
}
