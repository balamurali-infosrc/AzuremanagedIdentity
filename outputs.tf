output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "key_vault_uri" {
  description = "Key Vault vault_uri"
  value       = azurerm_key_vault.kv.vault_uri
}

output "vm_id" {
  description = "VM resource id"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_public_ip" {
  description = "VM public IP address"
  value       = azurerm_public_ip.pubip.ip_address
}

output "user_assigned_identity_client_id" {
  description = "User-assigned identity (client_id)"
  value       = azurerm_user_assigned_identity.uai.client_id
}
