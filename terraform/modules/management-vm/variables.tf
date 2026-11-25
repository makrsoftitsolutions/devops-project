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
  default = "Standard_B2s"
}

variable "bastion_subnet_cidr" {
  description = "CIDR of AzureBastionSubnet."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}