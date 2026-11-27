
variable "subscription_id" {
  description = "Azure subscription ID used by the AzureRM provider."
  type        = string
}

variable "location" {
  description = "Azure region for all environment resources."
  type        = string
}

variable "environment" {
  description = "Environment suffix used to generate names and identify this deployment's state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.environment))
    error_message = "Environment must be 2-8 lowercase letters or digits (for example dev, qa, uat, or prod)."
  }
}

variable "project" {
  description = "Short project identifier used in generated Azure resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.project))
    error_message = "Project must be 2-20 lowercase letters, digits, or hyphens."
  }
}

variable "tags" {
  description = "Additional tags applied to environment resources."
  type        = map(string)
  default     = {}
}

variable "hub_vnet_cidr" {
  description = "Hub VNet address spaces for this environment."
  type        = list(string)
}

variable "spoke_vnet_cidr" {
  description = "Spoke VNet address spaces for this environment."
  type        = list(string)
}

variable "hub_subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      contains(keys(var.hub_subnets), "AzureFirewallSubnet"),
      contains(keys(var.hub_subnets), "AzureBastionSubnet"),
      contains(keys(var.hub_subnets), "AzureFirewallManagementSubnet"),
      alltrue([for subnet in values(var.hub_subnets) : length(subnet.address_prefixes) > 0])
    ])
    error_message = "Configure AzureFirewallSubnet, AzureBastionSubnet, AzureFirewallManagementSubnet, and at least one prefix per hub subnet."
  }
}

variable "spoke_subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = optional(list(string), [])
    }))
  }))

  validation {
    condition = alltrue([
      contains(keys(var.spoke_subnets), "snet-aks"),
      contains(keys(var.spoke_subnets), "snet-appgw"),
      contains(keys(var.spoke_subnets), "snet-private"),
      contains(keys(var.spoke_subnets), "snet-workloads"),
      contains(keys(var.spoke_subnets), "snet-management"),
      alltrue([for subnet in values(var.spoke_subnets) : length(subnet.address_prefixes) > 0])
    ])
    error_message = "Configure snet-aks, snet-appgw, snet-private, snet-workloads, snet-management, and at least one prefix per spoke subnet."
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

variable "enable_firewall_management_ip" {
  description = "Create Azure Firewall's separate management public IP for forced tunneling. Leave off for normal deployments to conserve the regional public-IP quota."
  type        = bool
  default     = false
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

variable "application_gateway_zones" {
  description = "Availability zones for Application Gateway, or an empty list for regional placement."
  type        = list(string)
  default     = []
}

variable "enable_acr" {
  type    = bool
  default = false
}

variable "enable_acr_private_endpoint" {
  description = "Create an ACR private endpoint and private DNS. ACR must use Premium SKU and public access must be disabled."
  type        = bool
  default     = false
}

variable "acr_public_network_access_enabled" {
  description = "Keep ACR public access enabled for GitHub-hosted image build runners. Set false when using a VNet-connected runner and ACR private endpoint."
  type        = bool
  default     = true
}

variable "enable_aks" {
  type    = bool
  default = false
}

variable "enable_key_vault" {
  type    = bool
  default = false
}

variable "enable_postgres_flexible_server" {
  description = "Enable a private VNet-injected PostgreSQL Flexible Server and its initial database."
  type        = bool
  default     = false
}

variable "enable_storage_account" {
  description = "Enable a private StorageV2 account with a Blob private endpoint."
  type        = bool
  default     = false
}

variable "enable_event_hubs" {
  description = "Enable an Event Hubs namespace and event hub with a private endpoint."
  type        = bool
  default     = false
}

variable "enable_service_bus" {
  description = "Enable a Service Bus namespace and queue with a private endpoint."
  type        = bool
  default     = false
}

variable "enable_application_insights" {
  description = "Enable Application Insights linked to the Log Analytics workspace."
  type        = bool
  default     = false
}

variable "enable_azure_monitor_private_link" {
  description = "Enable Azure Monitor Private Link Scope, its private endpoint, and private DNS for Log Analytics/Application Insights."
  type        = bool
  default     = false
}

variable "postgres_flexible_server_name" {
  type    = string
  default = null
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_admin_username" {
  type    = string
  default = "pgadminuser"
}

variable "postgres_admin_password" {
  description = "Use TF_VAR_postgres_admin_password from a protected GitHub Environment secret; never commit it in tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "postgres_database_name" {
  type    = string
  default = "appdb"
}

variable "postgres_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_backup_retention_days" {
  type    = number
  default = 7
}

variable "postgres_zone" {
  type    = string
  default = null
}

variable "storage_account_name" {
  description = "Optional globally unique 3-24 character lowercase alphanumeric Storage account name."
  type        = string
  default     = null

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account names must contain 3-24 lowercase letters or digits."
  }
}

variable "storage_replication_type" {
  type    = string
  default = "LRS"
}

variable "event_hubs_namespace_name" {
  type    = string
  default = null
}

variable "event_hubs_sku" {
  type    = string
  default = "Standard"
}

variable "event_hubs_capacity" {
  type    = number
  default = 1
}

variable "event_hub_name" {
  type    = string
  default = "events"
}

variable "event_hub_partition_count" {
  type    = number
  default = 2
}

variable "event_hub_message_retention" {
  type    = number
  default = 1
}

variable "event_hubs_local_authentication_enabled" {
  description = "Enable SAS authentication when required by a client; otherwise use Entra ID."
  type        = bool
  default     = false
}

variable "service_bus_namespace_name" {
  type    = string
  default = null
}

variable "service_bus_sku" {
  type    = string
  default = "Standard"
}

variable "service_bus_queue_name" {
  type    = string
  default = "work-items"
}

variable "service_bus_local_auth_enabled" {
  description = "Enable SAS authentication when required by a client; otherwise use Entra ID."
  type        = bool
  default     = false
}

variable "application_insights_retention_days" {
  type    = number
  default = 90
}

variable "storage_blob_role_assignments" {
  description = "Optional app identity roles on Storage Blob. Map keys are stable Terraform keys."
  type = map(object({
    principal_id = string
    role_name    = string
  }))
  default = {}

  validation {
    condition     = alltrue([for assignment in values(var.storage_blob_role_assignments) : contains(["Storage Blob Data Reader", "Storage Blob Data Contributor"], assignment.role_name)])
    error_message = "Storage role assignments may use only Storage Blob Data Reader or Storage Blob Data Contributor."
  }
}

variable "event_hubs_role_assignments" {
  description = "Optional app identity roles on the Event Hubs namespace."
  type = map(object({
    principal_id = string
    role_name    = string
  }))
  default = {}

  validation {
    condition     = alltrue([for assignment in values(var.event_hubs_role_assignments) : contains(["Azure Event Hubs Data Receiver", "Azure Event Hubs Data Sender"], assignment.role_name)])
    error_message = "Event Hubs assignments may use only the Data Receiver or Data Sender role."
  }
}

variable "service_bus_role_assignments" {
  description = "Optional app identity roles on the Service Bus namespace."
  type = map(object({
    principal_id = string
    role_name    = string
  }))
  default = {}

  validation {
    condition     = alltrue([for assignment in values(var.service_bus_role_assignments) : contains(["Azure Service Bus Data Receiver", "Azure Service Bus Data Sender"], assignment.role_name)])
    error_message = "Service Bus assignments may use only the Data Receiver or Data Sender role."
  }
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "acr_name" {
  type    = string
  default = null

  validation {
    condition     = var.acr_name == null || can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "ACR names must contain 5-50 lowercase letters or digits."
  }
}

variable "key_vault_name" {
  type    = string
  default = null

  validation {
    condition     = var.key_vault_name == null ? true : (length(var.key_vault_name) >= 3 && length(var.key_vault_name) <= 24 && can(regex("^[a-zA-Z0-9-]+$", var.key_vault_name)))
    error_message = "Key Vault names must contain 3-24 letters, numbers, or hyphens."
  }
}

variable "aks_name" {
  type    = string
  default = null

  validation {
    condition     = var.aks_name == null ? true : (length(var.aks_name) >= 1 && length(var.aks_name) <= 63 && can(regex("^[a-zA-Z0-9-]+$", var.aks_name)))
    error_message = "AKS names must contain 1-63 letters, numbers, or hyphens."
  }
}

variable "aks_kubernetes_version" {
  type    = string
  default = null
}

variable "aks_private_cluster_enabled" {
  description = "Whether AKS uses a private API server endpoint; false enables public API access."
  type        = bool
  default     = true
}

variable "aks_system_node_count" {
  type    = number
  default = 1
}

variable "aks_system_vm_size" {
  type    = string
  default = "Standard_D2as_v7"
}

variable "aks_user_node_pool_name" {
  description = "Name for the Linux AKS user pool; limited to 12 lowercase alphanumeric characters."
  type        = string
  default     = "usernodepl1"
}

variable "aks_user_node_pool_vm_size" {
  description = "AKS-compatible Azure VM size for the user node pool."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "enable_aks_user_node_pool" {
  description = "Enable the autoscaling AKS user pool."
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
  default     = 1
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
  default     = "Standard_D2as_v7"
}

variable "management_vm_zone" {
  description = "Availability zone for the management VM, or null for regional placement."
  type        = string
  default     = null
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

