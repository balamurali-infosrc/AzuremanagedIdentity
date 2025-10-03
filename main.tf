terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">=1.5.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-managed-identity-demo"
  location = "EastUS"
}

# User-assigned Managed Identity
resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Example: Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "kv-demo-${random_id.suffix.hex}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
#   soft_delete_enabled         = true
  purge_protection_enabled    = false
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Role assignment for Key Vault access
resource "azurerm_role_assignment" "uai_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id

  depends_on = [azurerm_user_assigned_identity.uai]
}

# Optional: VM with the User-assigned identity
resource "azurerm_network_interface" "nic" {
  name                = "nic-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/<SUBNET>"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("CUsersBalamuraliRamakrishn.sshid_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }
}
