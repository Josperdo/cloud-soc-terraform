# ─── Public IP for Azure Bastion ─────────────────────────────────────────────
# Azure Bastion requires a Standard SKU static public IP.

resource "azurerm_public_ip" "bastion" {
  name                = "${var.prefix}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ─── Azure Bastion Host ───────────────────────────────────────────────────────
# Provides secure, browser-based SSH/RDP access to VMs without exposing
# any public IP on the VMs themselves.

resource "azurerm_bastion_host" "this" {
  name                = "${var.prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.bastion_sku
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
