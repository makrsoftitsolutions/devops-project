
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
    AzureFirewallSubnet           = { address_prefixes = ["10.0.1.0/26"] }
    AzureBastionSubnet            = { address_prefixes = ["10.0.2.0/26"] }
    AzureFirewallManagementSubnet = { address_prefixes = ["10.0.3.0/26"] }
  }
}

variable "spoke_subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
  default = {
    snet-aks        = { address_prefixes = ["10.1.0.0/22"] }
    snet-appgw      = { address_prefixes = ["10.1.4.0/24"] }
    snet-private    = { address_prefixes = ["10.1.5.0/24"] }
    snet-workloads  = { address_prefixes = ["10.1.6.0/24"] }
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

variable "enable_workload_firewall_default_route" {
  description = "Route workload-subnet internet egress through Azure Firewall. Enable only after configuring firewall allow rules."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "enable_application_gateway" {
  type    = bool
  default = false
}

variable "application_gateway_backend_fqdn" {
  description = "FQDN of the application backend, such as an AKS ingress endpoint."
  type        = string
  default     = null
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

variable "aks_user_node_pool_name" {
  description = "Name for the Linux AKS user pool; limited to 12 lowercase alphanumeric characters."
  type        = string
  default     = "usernodepl1"
}

variable "aks_user_node_pool_vm_size" {
  description = "Azure VM size for the AKS user node pool."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "enable_aks_user_node_pool" {
  description = "Enable the autoscaling AKS user pool after regional vCPU quota is available."
  type        = bool
  default     = true
}

variable "aks_user_node_pool_min_count" {
  description = "Minimum number of nodes maintained in the AKS user pool."
  type        = number
  default     = 1
}

variable "aks_user_node_pool_max_count" {
  description = "Maximum number of nodes for autoscaling in the AKS user pool."
  type        = number
  default     = 2
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

variable "management_vm_aks_rbac_role" {
  description = "AKS Azure RBAC permission granted to the management VM identity."
  type        = string
  default     = "Azure Kubernetes Service RBAC Reader"

  validation {
    condition = contains([
      "Azure Kubernetes Service RBAC Reader",
      "Azure Kubernetes Service RBAC Writer",
      "Azure Kubernetes Service RBAC Cluster Admin"
    ], var.management_vm_aks_rbac_role)
    error_message = "Choose the AKS RBAC Reader, Writer, or Cluster Admin role."
  }
}

variable "management_admin_ssh_public_key" {
  description = "SSH public key for management VM."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_aks_acr_pull" {
  description = "Enable AcrPull assignment for the AKS kubelet identity."
  type        = bool
  default     = false
}

variable "enable_acr_push" {
  description = "Grant the GitHub deployment service principal AcrPush on ACR for the image build workflow."
  type        = bool
  default     = false
}

variable "deployment_principal_object_id" {
  description = "Object ID of the GitHub Actions service principal that deploys this environment."
  type        = string
}

