variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-managed-identity-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "EastUS"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "VM admin username"
  type        = string
  default     = "azureuser"
}

# variable "ssh_public_key" {
#   description = "SSH public key for the VM (use TF_VAR_ssh_public_key or provide via variables)"
#   type        = string
#   sensitive   = true
#   default = "CUsersBalamuraliRamakrishn.sshid_rsa.pub"
# }
variable "ssh_public_keys" {
  type    = list(string)
  default = []   # empty list by default
}
