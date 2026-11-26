subscription_id = "aa61b080-74f9-41ed-a75f-8e60a60ccae4"

location    = "eastus"
environment = "dev"
project     = "makrsoft"

hub_vnet_cidr   = ["10.0.0.0/16"]
spoke_vnet_cidr = ["10.1.0.0/16"]

hub_subnets = {
  AzureFirewallSubnet           = { address_prefixes = ["10.0.1.0/26"] }
  AzureBastionSubnet            = { address_prefixes = ["10.0.2.0/26"] }
  AzureFirewallManagementSubnet = { address_prefixes = ["10.0.3.0/26"] }
}

spoke_subnets = {
  snet-aks        = { address_prefixes = ["10.1.0.0/22"] }
  snet-appgw      = { address_prefixes = ["10.1.4.0/24"] }
  snet-private    = { address_prefixes = ["10.1.5.0/24"] }
  snet-workloads  = { address_prefixes = ["10.1.6.0/24"] }
  snet-management = { address_prefixes = ["10.1.7.0/24"] }
  snet-postgres = {
    address_prefixes = ["10.1.8.0/24"]
    delegation = {
      name         = "postgres-flexible-server"
      service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

enable_log_analytics                    = true
enable_firewall                         = false
enable_firewall_management_ip           = false
enable_workload_firewall_default_route  = false
enable_bastion                          = true
enable_application_gateway              = false
application_gateway_backend_fqdn        = null
application_gateway_zones               = ["1", "2", "3"]
enable_acr                              = true
enable_acr_private_endpoint             = false
acr_public_network_access_enabled       = true
acr_sku                                 = "Basic"
key_vault_name                          = "kv-makrsoft-dev-002"
enable_acr_push                         = true
enable_aks                              = true
enable_aks_acr_pull                     = true
deployment_principal_object_id          = "33bf4292-01a6-45ef-a0be-8ce660ae9b53"
enable_key_vault                        = true
enable_postgres_flexible_server         = false
enable_storage_account                  = false
enable_event_hubs                       = false
enable_service_bus                      = false
enable_application_insights             = false
enable_azure_monitor_private_link       = true
postgres_flexible_server_name           = null
postgres_version                        = "16"
postgres_admin_username                 = "pgadminuser"
postgres_database_name                  = "appdb"
postgres_sku_name                       = "B_Standard_B1ms"
postgres_storage_mb                     = 32768
postgres_backup_retention_days          = 7
postgres_zone                           = null
storage_account_name                    = null
storage_replication_type                = "LRS"
event_hubs_namespace_name               = null
event_hubs_sku                          = "Standard"
event_hubs_capacity                     = 1
event_hub_name                          = "events"
event_hub_partition_count               = 2
event_hub_message_retention             = 1
event_hubs_local_authentication_enabled = false
service_bus_namespace_name              = null
service_bus_sku                         = "Standard"
service_bus_queue_name                  = "work-items"
service_bus_local_auth_enabled          = false
application_insights_retention_days     = 90
storage_blob_role_assignments           = {}
event_hubs_role_assignments             = {}
service_bus_role_assignments            = {}
enable_management_vm                    = true
management_vm_size                      = "Standard_B2s"
management_vm_zone                      = null
management_admin_username               = "azureadmin"
management_vm_aks_rbac_role             = "Azure Kubernetes Service RBAC Cluster Admin"
aks_user_node_pool_name                 = "usernodepl1"
aks_user_node_pool_vm_size              = "Standard_D4s_v5"
enable_aks_user_node_pool               = true
aks_system_vm_size                      = "Standard_D2as_v5"
aks_user_node_pool_min_count            = 1
aks_user_node_pool_max_count            = 2
management_admin_ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbJA7junOZmDFYgBAHZnRag93yNaHng3CkqWjU733WL aks-management-dev"

aks_admin_group_object_ids = [
  "0c0e6ddf-0da2-4d12-b4a1-038baffb01ad"
]

