variable "name" {
  description = "Linux management VM name."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  description = "Existing management subnet ID."
  type        = string
}

variable "network_security_group_name" {
  description = "Environment-specific network security group name for the management VM."
  type        = string
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for Linux VM authentication."
  type        = string
  sensitive   = true
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v7"
}

variable "user_assigned_identity_id" {
  description = "User-assigned identity attached to the management VM."
  type        = string
}

variable "user_assigned_identity_principal_id" {
  description = "Principal ID of the user-assigned identity attached to the management VM."
  type        = string
}

variable "zone" {
  description = "Availability zone for the management VM, or null for regional placement."
  type        = string
  default     = null
}

variable "bastion_subnet_cidr" {
  description = "CIDR of AzureBastionSubnet."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
