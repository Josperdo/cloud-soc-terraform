# ─── Network Interface ───────────────────────────────────────────────────────

resource "azurerm_network_interface" "this" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    # No public IP — access is exclusively via Azure Bastion.
  }
}

# ─── Linux Virtual Machine ───────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "this" {
  #checkov:skip=CKV_AZURE_50:AMA extension is intentionally installed — required for the Sentinel/Log Analytics monitoring pipeline
  name                            = var.vm_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  # System-assigned managed identity — allows the VM to authenticate to
  # Azure services (e.g., Key Vault, Log Analytics) without stored credentials.
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Empty block uses an Azure-managed storage account for boot diagnostics.
  # This avoids the cost and management overhead of a dedicated storage account.
  boot_diagnostics {}
}
