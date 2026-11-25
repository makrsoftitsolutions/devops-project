
variable "subscription_id" {
  description = "Azure subscription ID used by the AzureRM provider."
  type        = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "makrsoft"
}

variable "tags" {
  type = map(string)
  default = {
    project     = "devops-project"
    environment = "dev"
    managed_by  = "terraform"
  }
}

variable "hub_vnet_cidr" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "spoke_vnet_cidr" {
  type    = list(string)
  default = ["10.1.0.0/16"]
}

variable "hub_subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
  default = {
    AzureFirewallSubnet = { address_prefixes = ["10.0.1.0/26"] }
    AzureBastionSubnet  = { address_prefixes = ["10.0.2.0/26"] }
  }
}

variable "spoke_subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
  default = {
    snet-aks       = { address_prefixes = ["10.1.0.0/22"] }
    snet-appgw     = { address_prefixes = ["10.1.4.0/24"] }
    snet-private   = { address_prefixes = ["10.1.5.0/24"] }
    snet-workloads = { address_prefixes = ["10.1.6.0/24"] }
	snet-management = { address_prefixes = ["10.1.7.0/24"] }
  }
}

variable "enable_log_analytics" {
  type    = bool
  default = false
}

variable "enable_firewall" {
  type    = bool
  default = false
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "enable_application_gateway" {
  type    = bool
  default = false
}

variable "enable_acr" {
  type    = bool
  default = false
}

variable "enable_aks" {
  type    = bool
  default = false
}

variable "enable_key_vault" {
  type    = bool
  default = false
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "acr_name" {
  type    = string
  default = null
}

variable "key_vault_name" {
  type    = string
  default = null
}

variable "aks_name" {
  type    = string
  default = "aks-dev-platform"
}

variable "aks_kubernetes_version" {
  type    = string
  default = null
}

variable "aks_system_node_count" {
  type    = number
  default = 1
}

variable "aks_system_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "aks_admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "enable_management_vm" {
  description = "Enable the private Linux management VM."
  type        = bool
  default     = false
}

variable "management_vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "management_admin_username" {
  description = "Linux VM administrator username."
  type        = string
  default     = "azureadmin"
}

variable "management_admin_ssh_public_key" {
  description = "SSH public key for management VM."
  type        = string
  default     = null
  sensitive   = true
}