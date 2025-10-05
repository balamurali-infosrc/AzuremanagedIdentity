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
   subscription_id = "02a44fee-b200-4cf9-b042-9bd4aa3bebe6"
tenant_id = "63b9a1c1-375c-42cf-9c63-dc3798c7ae5e"
}

data "azurerm_client_config" "current" {}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -------------------------
# User-assigned Managed Identity
# -------------------------
resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# -------------------------
# Random suffix (for KV name uniqueness)
# -------------------------
resource "random_id" "suffix" {
  byte_length = 4
}

# -------------------------
# Key Vault
# -------------------------
resource "azurerm_key_vault" "kv" {
  name                        = "kv-demo-${random_id.suffix.hex}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7

  # Access policy block intentionally omitted in favor of RBAC role assignment.
  # Ensure your subscription allows Key Vault RBAC or adjust as needed.
 access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.uai.principal_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }
}
# Optional example secret
resource "azurerm_key_vault_secret" "example" {
  name         = "example-secret"
  value        = "example-value"
  key_vault_id = azurerm_key_vault.kv.id
}

# -------------------------
# Role assignment for Key Vault access (RBAC)
# -------------------------
resource "azurerm_role_assignment" "uai_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id

  depends_on = [azurerm_user_assigned_identity.uai,azurerm_key_vault.kv]
}

# -------------------------
# Networking: VNet, Subnet, Public IP, NIC
# -------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-demo"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pubip" {
  name                = "vm-demo-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"   # change from Basic
}
resource "azurerm_network_interface" "nic" {
  name                = "nic-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip.id
  }

  depends_on = [azurerm_subnet.subnet]
}

# -------------------------
# Linux VM with UserAssigned Identity
# -------------------------
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-demo"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

 dynamic "admin_ssh_key" {
    for_each = length(var.ssh_public_keys) > 0 ? { for idx, k in var.ssh_public_keys : idx => k } : {}

    content {
      username   = "azureuser"
      public_key = admin_ssh_key.value
    }
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

  # Ensure role assignment exists before VM creation (helps avoid some race issues)
  depends_on = [azurerm_role_assignment.uai_kv_access]
}
