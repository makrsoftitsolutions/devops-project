data "azurerm_client_config" "current" {}

locals {
  common_tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  })

  hub_rg_name     = "rg-network-${var.environment}"
  spoke_rg_name   = "rg-platform-${var.environment}"
  hub_vnet_name   = "vnet-hub-${var.environment}"
  spoke_vnet_name = "vnet-spoke-${var.environment}"

  workload_nsg_name          = "nsg-workloads-${var.environment}"
  workload_route_table_name  = "rt-workloads-${var.environment}"
  management_vm_name         = "vm-aks-management-${var.environment}"
  management_vm_nsg_name     = "nsg-management-${var.environment}"
  log_analytics_name         = "law-${var.project}-${var.environment}"
  firewall_name              = "afw-${var.project}-${var.environment}"
  bastion_name               = "bas-${var.project}-${var.environment}"
  application_gateway_name   = "appgw-${var.project}-${var.environment}"
  postgres_name              = coalesce(var.postgres_flexible_server_name, "psql-${var.project}-${var.environment}")
  storage_account_name       = coalesce(var.storage_account_name, substr(lower(replace("${var.project}${var.environment}st001", "-", "")), 0, 24))
  event_hubs_namespace_name  = coalesce(var.event_hubs_namespace_name, "eh-${var.project}-${var.environment}")
  service_bus_namespace_name = coalesce(var.service_bus_namespace_name, "sb-${var.project}-${var.environment}")
  application_insights_name  = "appi-${var.project}-${var.environment}"
  azure_monitor_scope_name   = "ampls-${var.project}-${var.environment}"

  azure_monitor_private_dns_zone_names = {
    monitor = "privatelink.monitor.azure.com"
    oms     = "privatelink.oms.opinsights.azure.com"
    ods     = "privatelink.ods.opinsights.azure.com"
    agents  = "privatelink.agentsvc.azure-automation.net"
  }

  acr_name = coalesce(
    var.acr_name,
    substr(lower(replace("${var.project}${var.environment}acr001", "-", "")), 0, 50)
  )
  aks_name       = coalesce(var.aks_name, "aks-${var.environment}-platform")
  key_vault_name = coalesce(var.key_vault_name, substr(lower("kv-${var.project}-${var.environment}-001"), 0, 24))
  aks_dns_prefix = "dns-${var.environment}-platform"

  role_definition_ids = {
    acr_pull                 = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    acr_push                 = "8311e382-0749-4cb8-b61a-304f252e45ec"
    network_contributor      = "4d97b98b-1d4f-4787-a291-c67834d212e7"
    resource_reader          = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    aks_cluster_user         = "4abbcc35-e782-43d8-92c5-2d3f1bd2253f"
    aks_rbac_reader          = "7f6c6a51-bcf8-42ba-9220-52d62157d7db"
    aks_rbac_writer          = "a7ffa36f-339b-4b5c-8bdf-e2c188b2c0eb"
    aks_rbac_cluster_admin   = "b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b"
    storage_blob_reader      = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
    storage_blob_contributor = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    event_hubs_receiver      = "a638d3c7-ab3a-418d-83e6-5f17a39d4fde"
    event_hubs_sender        = "2b629674-e913-4c01-ae53-ef4638d8f975"
    service_bus_receiver     = "4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0"
    service_bus_sender       = "69a216fc-b8fb-44d8-bc22-1f3c2cd27a39"
  }

  service_role_name_to_id = {
    "Storage Blob Data Reader"        = local.role_definition_ids.storage_blob_reader
    "Storage Blob Data Contributor"   = local.role_definition_ids.storage_blob_contributor
    "Azure Event Hubs Data Receiver"  = local.role_definition_ids.event_hubs_receiver
    "Azure Event Hubs Data Sender"    = local.role_definition_ids.event_hubs_sender
    "Azure Service Bus Data Receiver" = local.role_definition_ids.service_bus_receiver
    "Azure Service Bus Data Sender"   = local.role_definition_ids.service_bus_sender
  }

  azure_monitor_private_dns_links = var.enable_azure_monitor_private_link ? {
    for pair in setproduct(keys(local.azure_monitor_private_dns_zone_names), ["hub", "spoke"]) : "${pair[0]}-${pair[1]}" => {
      zone_key = pair[0]
      vnet_id  = pair[1] == "hub" ? module.hub_network.id : module.spoke_network.id
    }
  } : {}

  acr_delegated_role_pairs = concat(
    var.enable_aks && var.enable_aks_acr_pull ? [{
      role_definition_id = local.role_definition_ids.acr_pull
      principal_id       = try(module.aks[0].kubelet_identity_object_id, "")
    }] : [],
    var.enable_acr_push ? [{
      role_definition_id = local.role_definition_ids.acr_push
      principal_id       = var.deployment_principal_object_id
    }] : []
  )

  deployment_data_role_pairs = concat(
    var.enable_storage_account ? [
      for assignment in values(var.storage_blob_role_assignments) : {
        role_definition_id = local.service_role_name_to_id[assignment.role_name]
        principal_id       = assignment.principal_id
      }
    ] : [],
    var.enable_event_hubs ? [
      for assignment in values(var.event_hubs_role_assignments) : {
        role_definition_id = local.service_role_name_to_id[assignment.role_name]
        principal_id       = assignment.principal_id
      }
    ] : [],
    var.enable_service_bus ? [
      for assignment in values(var.service_bus_role_assignments) : {
        role_definition_id = local.service_role_name_to_id[assignment.role_name]
        principal_id       = assignment.principal_id
      }
    ] : []
  )

  deployment_delegated_role_pairs = concat(
    var.enable_aks ? [{
      role_definition_id = local.role_definition_ids.network_contributor
      principal_id       = try(module.aks_identity[0].principal_id, "")
    }] : [],
    var.enable_management_vm ? concat(
      [{
        role_definition_id = local.role_definition_ids.resource_reader
        principal_id       = try(module.management_vm[0].principal_id, "")
      }],
      var.enable_aks ? [
        {
          role_definition_id = local.role_definition_ids.aks_cluster_user
          principal_id       = try(module.management_vm[0].principal_id, "")
        },
        {
          role_definition_id = lookup({
            "Azure Kubernetes Service RBAC Reader"        = local.role_definition_ids.aks_rbac_reader
            "Azure Kubernetes Service RBAC Writer"        = local.role_definition_ids.aks_rbac_writer
            "Azure Kubernetes Service RBAC Cluster Admin" = local.role_definition_ids.aks_rbac_cluster_admin
          }, var.management_vm_aks_rbac_role, "")
          principal_id = try(module.management_vm[0].principal_id, "")
        }
      ] : []
    ) : [],
    local.deployment_data_role_pairs
  )

  deployment_role_assignment_write_condition = join(" OR ", [
    for pair in local.deployment_delegated_role_pairs : format(
      "(@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s} AND @Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {%s})",
      pair.role_definition_id,
      pair.principal_id
    )
  ])

  deployment_role_assignment_delete_condition = join(" OR ", [
    for pair in local.deployment_delegated_role_pairs : format(
      "(@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s} AND @Resource[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {%s})",
      pair.role_definition_id,
      pair.principal_id
    )
  ])

  deployment_role_assignment_condition = format(
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (%s)) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (%s))",
    local.deployment_role_assignment_write_condition,
    local.deployment_role_assignment_delete_condition
  )

  acr_role_assignment_write_condition = join(" OR ", [
    for pair in local.acr_delegated_role_pairs : format(
      "(@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s} AND @Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {%s})",
      pair.role_definition_id,
      pair.principal_id
    )
  ])

  acr_role_assignment_delete_condition = join(" OR ", [
    for pair in local.acr_delegated_role_pairs : format(
      "(@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s} AND @Resource[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {%s})",
      pair.role_definition_id,
      pair.principal_id
    )
  ])

  acr_role_assignment_condition = format(
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (%s)) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (%s))",
    local.acr_role_assignment_write_condition,
    local.acr_role_assignment_delete_condition
  )

  workload_routes = var.enable_workload_firewall_default_route ? {
    default_to_firewall = {
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.firewall[0].private_ip
    }
  } : {}
}

resource "terraform_data" "firewall_route_guard" {
  input = var.enable_workload_firewall_default_route

  lifecycle {
    precondition {
      condition     = !var.enable_workload_firewall_default_route || var.enable_firewall
      error_message = "Enable Azure Firewall before routing workload traffic through it."
    }
  }
}

resource "azurerm_resource_group" "hub" {
  name     = local.hub_rg_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spoke" {
  name     = local.spoke_rg_name
  location = var.location
  tags     = local.common_tags
}

module "hub_network" {
  source              = "../modules/network"
  name                = local.hub_vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.hub_vnet_cidr
  subnets             = var.hub_subnets
  tags                = local.common_tags
}

module "spoke_network" {
  source              = "../modules/network"
  name                = local.spoke_vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.spoke_vnet_cidr
  subnets             = var.spoke_subnets
  tags                = local.common_tags
}

resource "terraform_data" "new_services_guard" {
  input = {
    enable_postgres_flexible_server   = var.enable_postgres_flexible_server
    enable_application_insights       = var.enable_application_insights
    enable_azure_monitor_private_link = var.enable_azure_monitor_private_link
  }

  lifecycle {
    precondition {
      condition     = !var.enable_postgres_flexible_server || try(trimspace(var.postgres_admin_password) != "", false)
      error_message = "Set TF_VAR_postgres_admin_password through a protected GitHub Environment secret before enabling PostgreSQL. Do not commit database passwords in terraform.tfvars."
    }
    precondition {
      condition = !var.enable_postgres_flexible_server || (
        contains(keys(var.spoke_subnets), "snet-postgres") &&
        try(var.spoke_subnets["snet-postgres"].delegation.service_name == "Microsoft.DBforPostgreSQL/flexibleServers", false)
      )
      error_message = "When PostgreSQL is enabled, configure snet-postgres with the Microsoft.DBforPostgreSQL/flexibleServers subnet delegation."
    }
    precondition {
      condition     = !var.enable_application_insights || var.enable_log_analytics
      error_message = "Enable Log Analytics before Application Insights so telemetry has a workspace destination."
    }
    precondition {
      condition     = !var.enable_azure_monitor_private_link || var.enable_log_analytics
      error_message = "Enable Log Analytics before Azure Monitor Private Link."
    }
    precondition {
      condition     = !var.enable_acr_private_endpoint || (var.enable_acr && upper(var.acr_sku) == "PREMIUM")
      error_message = "An ACR private endpoint requires ACR to be enabled with Premium SKU."
    }
    precondition {
      condition     = !var.enable_acr_private_endpoint || !var.acr_public_network_access_enabled
      error_message = "Disable ACR public network access when its private endpoint is enabled."
    }
    precondition {
      condition     = length(var.storage_blob_role_assignments) == 0 || var.enable_storage_account
      error_message = "Enable the Storage Account before configuring its Blob data role assignments."
    }
    precondition {
      condition     = length(var.event_hubs_role_assignments) == 0 || var.enable_event_hubs
      error_message = "Enable Event Hubs before configuring Event Hubs data role assignments."
    }
    precondition {
      condition     = length(var.service_bus_role_assignments) == 0 || var.enable_service_bus
      error_message = "Enable Service Bus before configuring Service Bus data role assignments."
    }
  }
}

module "spoke_nsg" {
  source              = "../modules/nsg"
  name                = local.workload_nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

# Keep the default NSG association limited to the general workload subnet.
# AzureFirewallSubnet, AzureBastionSubnet and the Application Gateway subnet
# have service-specific network requirements and are intentionally excluded.
resource "azurerm_subnet_network_security_group_association" "workloads" {
  subnet_id                 = module.spoke_network.subnet_ids["snet-workloads"]
  network_security_group_id = module.spoke_nsg.id
}

module "workloads_route_table" {
  source              = "../modules/route-table"
  name                = local.workload_route_table_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  routes              = local.workload_routes
  tags                = local.common_tags
}

resource "azurerm_subnet_route_table_association" "workloads" {
  subnet_id      = module.spoke_network.subnet_ids["snet-workloads"]
  route_table_id = module.workloads_route_table.id
}

module "hub_to_spoke" {
  source                    = "../modules/peering"
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = module.hub_network.name
  remote_virtual_network_id = module.spoke_network.id
}

module "spoke_to_hub" {
  source                    = "../modules/peering"
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.spoke.name
  virtual_network_name      = module.spoke_network.name
  remote_virtual_network_id = module.hub_network.id
}

resource "terraform_data" "management_vm_ssh_key_guard" {
  input = var.management_admin_ssh_public_key

  lifecycle {
    precondition {
      condition = !var.enable_management_vm || (
        var.management_admin_ssh_public_key != null &&
        trimspace(var.management_admin_ssh_public_key) != ""
      )

      error_message = "Provide management_admin_ssh_public_key before enabling the management VM."
    }
  }
}

module "management_vm" {
  count  = var.enable_management_vm ? 1 : 0
  source = "../modules/management-vm"

  name                = local.management_vm_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name

  subnet_id = module.spoke_network.subnet_ids["snet-management"]

  admin_username       = var.management_admin_username
  admin_ssh_public_key = var.management_admin_ssh_public_key
  vm_size              = var.management_vm_size
  zone                 = var.management_vm_zone

  network_security_group_name = local.management_vm_nsg_name
  bastion_subnet_cidr         = var.hub_subnets["AzureBastionSubnet"].address_prefixes[0]

  tags = local.common_tags

  depends_on = [
    module.hub_to_spoke,
    module.spoke_to_hub,
    terraform_data.management_vm_ssh_key_guard
  ]
}

module "log_analytics" {
  count               = var.enable_log_analytics ? 1 : 0
  source              = "../modules/log-analytics"
  name                = local.log_analytics_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

module "firewall" {
  count                = var.enable_firewall ? 1 : 0
  source               = "../modules/firewall"
  name                 = local.firewall_name
  location             = var.location
  resource_group_name  = azurerm_resource_group.hub.name
  subnet_id            = module.hub_network.subnet_ids["AzureFirewallSubnet"]
  management_subnet_id = module.hub_network.subnet_ids["AzureFirewallManagementSubnet"]
  tags                 = local.common_tags
}

module "bastion" {
  count               = var.enable_bastion ? 1 : 0
  source              = "../modules/bastion"
  name                = local.bastion_name
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = module.hub_network.subnet_ids["AzureBastionSubnet"]
  tags                = local.common_tags
}

module "application_gateway" {
  count               = var.enable_application_gateway ? 1 : 0
  source              = "../modules/application-gateway"
  name                = local.application_gateway_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = module.spoke_network.subnet_ids["snet-appgw"]
  backend_fqdn        = var.application_gateway_backend_fqdn
  zones               = var.application_gateway_zones
  tags                = local.common_tags

  # When AKS is enabled, wait for its private cluster before provisioning the gateway.
  depends_on = [module.aks]
}

module "acr" {
  count                         = var.enable_acr ? 1 : 0
  source                        = "../modules/acr"
  name                          = local.acr_name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.spoke.name
  sku                           = var.acr_sku
  public_network_access_enabled = var.acr_public_network_access_enabled
  tags                          = local.common_tags
}

module "aks_identity" {
  count               = var.enable_aks ? 1 : 0
  source              = "../modules/identity"
  name                = "id-${local.aks_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

module "rbac_aks_network" {
  count  = var.enable_aks ? 1 : 0
  source = "../modules/rbac"

  assignments = {
    aks_network_contributor = {
      scope                = module.spoke_network.subnet_ids["snet-aks"]
      role_definition_name = "Network Contributor"
      principal_id         = module.aks_identity[0].principal_id
    }
  }
}

# This assignment is bootstrapped once by an Azure identity that already has
# roleAssignments/write on the ACR. Afterward, the GitHub OIDC identity can
# manage the AKS AcrPull assignment through Terraform.
module "rbac_deployment_acr_admin" {
  count = (
    var.enable_acr &&
    ((var.enable_aks && var.enable_aks_acr_pull) || var.enable_acr_push)
  ) ? 1 : 0
  source = "../modules/rbac"

  assignments = {
    deployment_acr_rbac_admin = {
      scope                = module.acr[0].id
      role_definition_name = "Role Based Access Control Administrator"
      principal_id         = var.deployment_principal_object_id
      condition_version    = "2.0"
      condition            = local.acr_role_assignment_condition
    }
  }
}

module "rbac_acr_push" {
  count = (
    var.enable_acr &&
    var.enable_acr_push
  ) ? 1 : 0
  source = "../modules/rbac"

  assignments = {
    deployment_acr_push = {
      scope                = module.acr[0].id
      role_definition_name = "AcrPush"
      principal_id         = var.deployment_principal_object_id
    }
  }

  depends_on = [module.rbac_deployment_acr_admin]
}

module "aks" {
  count                      = var.enable_aks ? 1 : 0
  source                     = "../modules/aks"
  name                       = local.aks_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.spoke.name
  dns_prefix                 = local.aks_dns_prefix
  kubernetes_version         = var.aks_kubernetes_version
  subnet_id                  = module.spoke_network.subnet_ids["snet-aks"]
  identity_id                = module.aks_identity[0].id
  system_node_count          = var.aks_system_node_count
  system_vm_size             = var.aks_system_vm_size
  enable_user_node_pool      = var.enable_aks_user_node_pool
  user_node_pool_name        = var.aks_user_node_pool_name
  user_node_pool_vm_size     = var.aks_user_node_pool_vm_size
  user_node_pool_min_count   = var.aks_user_node_pool_min_count
  user_node_pool_max_count   = var.aks_user_node_pool_max_count
  admin_group_object_ids     = var.aks_admin_group_object_ids
  log_analytics_workspace_id = var.enable_log_analytics ? module.log_analytics[0].id : null
  tags                       = local.common_tags
  depends_on                 = [module.rbac_aks_network]
}

# The GitHub deployment identity must already have roleAssignments/write at the
# ACR scope (for example, Role Based Access Control Administrator).
module "rbac_aks_acr_pull" {
  count = (
    var.enable_aks &&
    var.enable_acr &&
    var.enable_aks_acr_pull
  ) ? 1 : 0
  source = "../modules/rbac"

  assignments = {
    aks_acr_pull = {
      scope                = module.acr[0].id
      role_definition_name = "AcrPull"
      principal_id         = module.aks[0].kubelet_identity_object_id
    }
  }

  depends_on = [module.rbac_deployment_acr_admin]
}

# Delegates only the role assignments required by the management VM, and only
# for that VM's identity. Bootstrap this grant with an already authorized Azure
# identity; the GitHub identity cannot create its own initial authorization.
module "rbac_deployment_management" {
  count  = length(local.deployment_delegated_role_pairs) > 0 ? 1 : 0
  source = "../modules/rbac"

  assignments = {
    deployment_manage_vm_roles = {
      scope                = azurerm_resource_group.spoke.id
      role_definition_name = "Role Based Access Control Administrator"
      principal_id         = var.deployment_principal_object_id
      condition_version    = "2.0"
      condition            = local.deployment_role_assignment_condition
    }
  }
}

module "rbac_management_vm" {
  count  = var.enable_management_vm ? 1 : 0
  source = "../modules/rbac"

  assignments = merge(
    {
      management_vm_resource_reader = {
        scope                = azurerm_resource_group.spoke.id
        role_definition_name = "Reader"
        principal_id         = module.management_vm[0].principal_id
      }
    },
    var.enable_aks ? {
      management_vm_aks_cluster_user = {
        scope                = module.aks[0].id
        role_definition_name = "Azure Kubernetes Service Cluster User Role"
        principal_id         = module.management_vm[0].principal_id
      }
      management_vm_aks_rbac = {
        scope                = module.aks[0].id
        role_definition_name = var.management_vm_aks_rbac_role
        principal_id         = module.management_vm[0].principal_id
      }
    } : {}
  )

  depends_on = [module.rbac_deployment_management]
}

# Preserve existing role assignment state while moving the resources into the reusable module.
moved {
  from = azurerm_role_assignment.aks_network_contributor[0]
  to   = module.rbac_aks_network[0].azurerm_role_assignment.this["aks_network_contributor"]
}

moved {
  from = azurerm_role_assignment.deployment_acr_rbac_admin[0]
  to   = module.rbac_deployment_acr_admin[0].azurerm_role_assignment.this["deployment_acr_rbac_admin"]
}

moved {
  from = azurerm_role_assignment.deployment_acr_push[0]
  to   = module.rbac_acr_push[0].azurerm_role_assignment.this["deployment_acr_push"]
}

moved {
  from = azurerm_role_assignment.aks_acr_pull[0]
  to   = module.rbac_aks_acr_pull[0].azurerm_role_assignment.this["aks_acr_pull"]
}

resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_acr_private_endpoint ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_spoke" {
  count                 = var.enable_acr_private_endpoint ? 1 : 0
  name                  = "link-acr-${var.environment}-spoke"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = module.spoke_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  count                 = var.enable_acr_private_endpoint ? 1 : 0
  name                  = "link-acr-${var.environment}-hub"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = module.hub_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "acr_private_endpoint" {
  count  = var.enable_acr_private_endpoint ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-acr"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.acr[0].id
  subresource_names              = ["registry"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.acr[0].id]
  tags                           = local.common_tags

  depends_on = [
    terraform_data.new_services_guard,
    azurerm_private_dns_zone_virtual_network_link.acr_spoke,
    azurerm_private_dns_zone_virtual_network_link.acr_hub
  ]
}

module "key_vault" {
  count               = var.enable_key_vault ? 1 : 0
  source              = "../modules/key-vault"
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "key_vault" {
  count               = var.enable_key_vault ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count                 = var.enable_key_vault ? 1 : 0
  name                  = "link-key-vault-${var.environment}-spoke"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = module.spoke_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault_hub" {
  count                 = var.enable_key_vault ? 1 : 0
  name                  = "link-key-vault-${var.environment}-hub"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = module.hub_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "key_vault_private_endpoint" {
  count  = var.enable_key_vault ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-kv"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.key_vault[0].id
  subresource_names              = ["vault"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.key_vault[0].id]
  tags                           = local.common_tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.key_vault,
    azurerm_private_dns_zone_virtual_network_link.key_vault_hub
  ]
}

# PostgreSQL Flexible Server private access is VNet-injected: the server uses
# a dedicated delegated subnet and a private DNS zone, rather than a PE.
resource "azurerm_private_dns_zone" "postgres" {
  count               = var.enable_postgres_flexible_server ? 1 : 0
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.enable_postgres_flexible_server ? 1 : 0
  name                  = "link-postgres-${var.environment}-spoke"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = module.spoke_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_hub" {
  count                 = var.enable_postgres_flexible_server ? 1 : 0
  name                  = "link-postgres-${var.environment}-hub"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = module.hub_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "postgres_flexible_server" {
  count  = var.enable_postgres_flexible_server ? 1 : 0
  source = "../modules/postgres-flexible-server"

  name                   = local.postgres_name
  location               = var.location
  resource_group_name    = azurerm_resource_group.spoke.name
  postgres_version       = var.postgres_version
  delegated_subnet_id    = try(module.spoke_network.subnet_ids["snet-postgres"], null)
  private_dns_zone_id    = azurerm_private_dns_zone.postgres[0].id
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  database_name          = var.postgres_database_name
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb
  backup_retention_days  = var.postgres_backup_retention_days
  zone                   = var.postgres_zone
  tags                   = local.common_tags
  depends_on             = [azurerm_private_dns_zone_virtual_network_link.postgres, azurerm_private_dns_zone_virtual_network_link.postgres_hub, terraform_data.new_services_guard]
}

module "storage_account" {
  count  = var.enable_storage_account ? 1 : 0
  source = "../modules/storage-account"

  name                = local.storage_account_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  replication_type    = var.storage_replication_type
  tags                = local.common_tags
}

module "event_hubs" {
  count  = var.enable_event_hubs ? 1 : 0
  source = "../modules/event-hubs"

  name                         = local.event_hubs_namespace_name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.spoke.name
  sku                          = var.event_hubs_sku
  capacity                     = var.event_hubs_capacity
  event_hub_name               = var.event_hub_name
  partition_count              = var.event_hub_partition_count
  message_retention            = var.event_hub_message_retention
  local_authentication_enabled = var.event_hubs_local_authentication_enabled
  tags                         = local.common_tags
}

module "service_bus" {
  count  = var.enable_service_bus ? 1 : 0
  source = "../modules/service-bus"

  name                = local.service_bus_namespace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  sku                 = var.service_bus_sku
  queue_name          = var.service_bus_queue_name
  local_auth_enabled  = var.service_bus_local_auth_enabled
  tags                = local.common_tags
}

module "application_insights" {
  count  = var.enable_application_insights ? 1 : 0
  source = "../modules/application-insights"

  name                       = local.application_insights_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.spoke.name
  log_analytics_workspace_id = module.log_analytics[0].id
  retention_in_days          = var.application_insights_retention_days
  tags                       = local.common_tags
  depends_on                 = [terraform_data.new_services_guard]
}

module "azure_monitor_private_link" {
  count  = var.enable_azure_monitor_private_link ? 1 : 0
  source = "../modules/azure-monitor-private-link"

  name                = local.azure_monitor_scope_name
  resource_group_name = azurerm_resource_group.spoke.name
  linked_resource_ids = merge(
    var.enable_log_analytics ? { log_analytics = module.log_analytics[0].id } : {},
    var.enable_application_insights ? { application_insights = module.application_insights[0].id } : {}
  )
  tags = local.common_tags

  depends_on = [terraform_data.new_services_guard]
}

resource "azurerm_private_dns_zone" "azure_monitor" {
  for_each = var.enable_azure_monitor_private_link ? local.azure_monitor_private_dns_zone_names : {}

  name                = each.value
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "azure_monitor" {
  for_each = local.azure_monitor_private_dns_links

  name                  = "link-${each.key}-${var.environment}"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.azure_monitor[each.value.zone_key].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "azure_monitor_private_endpoint" {
  count  = var.enable_azure_monitor_private_link ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-monitor"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.azure_monitor_private_link[0].id
  subresource_names              = ["azuremonitor"]
  private_dns_zone_ids = concat(
    [azurerm_private_dns_zone.storage_blob[0].id],
    [for zone in values(azurerm_private_dns_zone.azure_monitor) : zone.id]
  )
  tags = local.common_tags
  depends_on = [
    module.azure_monitor_private_link,
    azurerm_private_dns_zone_virtual_network_link.storage_blob,
    azurerm_private_dns_zone_virtual_network_link.storage_blob_hub,
    azurerm_private_dns_zone_virtual_network_link.azure_monitor
  ]
}

# Reuse a single private DNS zone/link for messaging endpoints; the Azure DNS
# zone is shared by Event Hubs and Service Bus.
resource "azurerm_private_dns_zone" "messaging" {
  count               = var.enable_event_hubs || var.enable_service_bus ? 1 : 0
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "messaging" {
  count                 = var.enable_event_hubs || var.enable_service_bus ? 1 : 0
  name                  = "link-messaging-${var.environment}-spoke"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.messaging[0].name
  virtual_network_id    = module.spoke_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "messaging_hub" {
  count                 = var.enable_event_hubs || var.enable_service_bus ? 1 : 0
  name                  = "link-messaging-${var.environment}-hub"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.messaging[0].name
  virtual_network_id    = module.hub_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone" "storage_blob" {
  count               = var.enable_storage_account || var.enable_azure_monitor_private_link ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  count                 = var.enable_storage_account || var.enable_azure_monitor_private_link ? 1 : 0
  name                  = "link-blob-${var.environment}-spoke"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = module.spoke_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob_hub" {
  count                 = var.enable_storage_account || var.enable_azure_monitor_private_link ? 1 : 0
  name                  = "link-blob-${var.environment}-hub"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = module.hub_network.id
  registration_enabled  = false
  tags                  = local.common_tags
}

module "storage_private_endpoint" {
  count  = var.enable_storage_account ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-storage-blob"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.storage_account[0].id
  subresource_names              = ["blob"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.storage_blob[0].id]
  tags                           = local.common_tags
  depends_on                     = [azurerm_private_dns_zone_virtual_network_link.storage_blob, azurerm_private_dns_zone_virtual_network_link.storage_blob_hub]
}

module "event_hubs_private_endpoint" {
  count  = var.enable_event_hubs ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-eventhubs"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.event_hubs[0].namespace_id
  subresource_names              = ["namespace"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.messaging[0].id]
  tags                           = local.common_tags
  depends_on                     = [azurerm_private_dns_zone_virtual_network_link.messaging, azurerm_private_dns_zone_virtual_network_link.messaging_hub]
}

module "service_bus_private_endpoint" {
  count  = var.enable_service_bus ? 1 : 0
  source = "../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-servicebus"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.service_bus[0].namespace_id
  subresource_names              = ["namespace"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.messaging[0].id]
  tags                           = local.common_tags
  depends_on                     = [azurerm_private_dns_zone_virtual_network_link.messaging, azurerm_private_dns_zone_virtual_network_link.messaging_hub]
}

locals {
  monitored_resource_ids = merge(
    var.enable_postgres_flexible_server ? { postgres = module.postgres_flexible_server[0].id } : {},
    var.enable_storage_account ? { storage = module.storage_account[0].id } : {},
    var.enable_event_hubs ? { event_hubs = module.event_hubs[0].namespace_id } : {},
    var.enable_service_bus ? { service_bus = module.service_bus[0].namespace_id } : {}
  )

  application_data_role_assignments = merge(
    var.enable_storage_account ? {
      for key, assignment in var.storage_blob_role_assignments : "storage_${key}" => {
        scope                = module.storage_account[0].id
        role_definition_name = assignment.role_name
        principal_id         = assignment.principal_id
      }
    } : {},
    var.enable_event_hubs ? {
      for key, assignment in var.event_hubs_role_assignments : "event_hubs_${key}" => {
        scope                = module.event_hubs[0].event_hub_id
        role_definition_name = assignment.role_name
        principal_id         = assignment.principal_id
      }
    } : {},
    var.enable_service_bus ? {
      for key, assignment in var.service_bus_role_assignments : "service_bus_${key}" => {
        scope                = module.service_bus[0].queue_id
        role_definition_name = assignment.role_name
        principal_id         = assignment.principal_id
      }
    } : {}
  )
}

module "monitor_diagnostics" {
  for_each = var.enable_log_analytics ? local.monitored_resource_ids : {}
  source   = "../modules/monitor-diagnostics"

  name                       = "diag-${each.key}-${var.environment}"
  target_resource_id         = each.value
  log_analytics_workspace_id = module.log_analytics[0].id
}

module "rbac_application_data" {
  count  = length(local.application_data_role_assignments) > 0 ? 1 : 0
  source = "../modules/rbac"

  assignments = local.application_data_role_assignments

  depends_on = [module.rbac_deployment_management]
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "hub_resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "spoke_resource_group_name" {
  value = azurerm_resource_group.spoke.name
}

output "hub_vnet_id" {
  value = module.hub_network.id
}

output "spoke_vnet_id" {
  value = module.spoke_network.id
}

output "hub_subnet_ids" {
  value = module.hub_network.subnet_ids
}

output "spoke_subnet_ids" {
  value = module.spoke_network.subnet_ids
}

output "log_analytics_workspace_id" {
  value = var.enable_log_analytics ? module.log_analytics[0].id : null
}

output "firewall_public_ip" {
  value = var.enable_firewall ? module.firewall[0].public_ip : null
}

output "acr_login_server" {
  value = var.enable_acr ? module.acr[0].login_server : null
}

output "acr_private_endpoint_ip" {
  value = var.enable_acr_private_endpoint ? module.acr_private_endpoint[0].private_ip_addresses : null
}

output "aks_name" {
  value = var.enable_aks ? module.aks[0].name : null
}

output "aks_user_node_pool_name" {
  value = var.enable_aks ? module.aks[0].user_node_pool_name : null
}

output "key_vault_uri" {
  value = var.enable_key_vault ? module.key_vault[0].vault_uri : null
}

output "key_vault_private_endpoint_ip" {
  value = var.enable_key_vault ? module.key_vault_private_endpoint[0].private_ip_addresses : null
}

output "storage_private_endpoint_ip" {
  value = var.enable_storage_account ? module.storage_private_endpoint[0].private_ip_addresses : null
}

output "event_hubs_private_endpoint_ip" {
  value = var.enable_event_hubs ? module.event_hubs_private_endpoint[0].private_ip_addresses : null
}

output "service_bus_private_endpoint_ip" {
  value = var.enable_service_bus ? module.service_bus_private_endpoint[0].private_ip_addresses : null
}

output "azure_monitor_private_endpoint_ip" {
  value = var.enable_azure_monitor_private_link ? module.azure_monitor_private_endpoint[0].private_ip_addresses : null
}

output "postgres_flexible_server_fqdn" {
  value = var.enable_postgres_flexible_server ? module.postgres_flexible_server[0].fqdn : null
}

output "postgres_database_name" {
  value = var.enable_postgres_flexible_server ? module.postgres_flexible_server[0].database_name : null
}

output "storage_account_name" {
  value = var.enable_storage_account ? module.storage_account[0].name : null
}

output "storage_blob_endpoint" {
  value = var.enable_storage_account ? module.storage_account[0].primary_blob_endpoint : null
}

output "event_hubs_namespace_name" {
  value = var.enable_event_hubs ? module.event_hubs[0].namespace_name : null
}

output "service_bus_namespace_name" {
  value = var.enable_service_bus ? module.service_bus[0].namespace_name : null
}

output "application_insights_connection_string" {
  value     = var.enable_application_insights ? module.application_insights[0].connection_string : null
  sensitive = true
}

output "management_vm_name" {
  value = var.enable_management_vm ? module.management_vm[0].vm_name : null
}

output "management_vm_id" {
  value = var.enable_management_vm ? module.management_vm[0].vm_id : null
}

output "management_vm_private_ip" {
  value = var.enable_management_vm ? module.management_vm[0].private_ip_address : null
}

output "management_vm_principal_id" {
  value = var.enable_management_vm ? module.management_vm[0].principal_id : null
}
