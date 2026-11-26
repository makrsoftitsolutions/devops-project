data "azurerm_client_config" "current" {}

locals {
  common_tags = merge(var.tags, {
    environment = var.environment
  })

  hub_rg_name   = "rg-network-${var.environment}"
  spoke_rg_name = "rg-platform-${var.environment}"

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
  source              = "../../modules/network"
  name                = "vnet-hub-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.hub_vnet_cidr
  subnets             = var.hub_subnets
  tags                = local.common_tags
}

module "spoke_network" {
  source              = "../../modules/network"
  name                = "vnet-spoke-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.spoke_vnet_cidr
  subnets             = var.spoke_subnets
  tags                = local.common_tags
}

module "spoke_nsg" {
  source              = "../../modules/nsg"
  name                = "nsg-workloads-${var.environment}"
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
  source              = "../../modules/route-table"
  name                = "rt-workloads-${var.environment}"
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
  source                    = "../../modules/peering"
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = module.hub_network.name
  remote_virtual_network_id = module.spoke_network.id
}

module "spoke_to_hub" {
  source                    = "../../modules/peering"
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
  source = "../../modules/management-vm"

  name                = "vm-aks-management-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name

  subnet_id = module.spoke_network.subnet_ids["snet-management"]

  admin_username       = var.management_admin_username
  admin_ssh_public_key = var.management_admin_ssh_public_key
  vm_size              = var.management_vm_size

  bastion_subnet_cidr = "10.0.2.0/26"

  tags = local.common_tags

  depends_on = [
    module.hub_to_spoke,
    module.spoke_to_hub,
    terraform_data.management_vm_ssh_key_guard
  ]
}

module "log_analytics" {
  count               = var.enable_log_analytics ? 1 : 0
  source              = "../../modules/log-analytics"
  name                = "law-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

module "firewall" {
  count                = var.enable_firewall ? 1 : 0
  source               = "../../modules/firewall"
  name                 = "afw-${var.project}-${var.environment}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.hub.name
  subnet_id            = module.hub_network.subnet_ids["AzureFirewallSubnet"]
  management_subnet_id = module.hub_network.subnet_ids["AzureFirewallManagementSubnet"]
  tags                 = local.common_tags
}

module "bastion" {
  count               = var.enable_bastion ? 1 : 0
  source              = "../../modules/bastion"
  name                = "bas-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = module.hub_network.subnet_ids["AzureBastionSubnet"]
  tags                = local.common_tags
}

module "application_gateway" {
  count               = var.enable_application_gateway ? 1 : 0
  source              = "../../modules/application-gateway"
  name                = "appgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = module.spoke_network.subnet_ids["snet-appgw"]
  backend_fqdn        = var.application_gateway_backend_fqdn
  tags                = local.common_tags
}

module "acr" {
  count               = var.enable_acr ? 1 : 0
  source              = "../../modules/acr"
  name                = coalesce(var.acr_name, substr(replace("${var.project}${var.environment}acr", "-", ""), 0, 50))
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "aks_identity" {
  count               = var.enable_aks ? 1 : 0
  source              = "../../modules/identity"
  name                = "id-${var.aks_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  count                = var.enable_aks ? 1 : 0
  scope                = module.spoke_network.subnet_ids["snet-aks"]
  role_definition_name = "Network Contributor"
  principal_id         = module.aks_identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# This assignment is bootstrapped once by an Azure identity that already has
# roleAssignments/write on the ACR. Afterward, the GitHub OIDC identity can
# manage the AKS AcrPull assignment through Terraform.
resource "azurerm_role_assignment" "deployment_acr_rbac_admin" {
  count = (
    var.enable_acr &&
    (var.enable_aks_acr_pull || var.enable_acr_push)
  ) ? 1 : 0

  scope                = module.acr[0].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = var.deployment_principal_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deployment_acr_push" {
  count = (
    var.enable_acr &&
    var.enable_acr_push
  ) ? 1 : 0

  scope                = module.acr[0].id
  role_definition_name = "AcrPush"
  principal_id         = var.deployment_principal_object_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_role_assignment.deployment_acr_rbac_admin]
}

module "aks" {
  count                      = var.enable_aks ? 1 : 0
  source                     = "../../modules/aks"
  name                       = var.aks_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.spoke.name
  dns_prefix                 = "dns-${var.environment}-platform"
  kubernetes_version         = var.aks_kubernetes_version
  subnet_id                  = module.spoke_network.subnet_ids["snet-aks"]
  identity_id                = module.aks_identity[0].id
  system_node_count          = var.aks_system_node_count
  system_vm_size             = var.aks_system_vm_size
  admin_group_object_ids     = var.aks_admin_group_object_ids
  log_analytics_workspace_id = var.enable_log_analytics ? module.log_analytics[0].id : null
  tags                       = local.common_tags
  depends_on                 = [azurerm_role_assignment.aks_network_contributor]
}

# The GitHub deployment identity must already have roleAssignments/write at the
# ACR scope (for example, Role Based Access Control Administrator).
resource "azurerm_role_assignment" "aks_acr_pull" {
  count = (
    var.enable_aks &&
    var.enable_acr &&
    var.enable_aks_acr_pull
  ) ? 1 : 0

  scope                = module.acr[0].id
  role_definition_name = "AcrPull"

  principal_id = module.aks[0].kubelet_identity_object_id

  principal_type = "ServicePrincipal"

  depends_on = [azurerm_role_assignment.deployment_acr_rbac_admin]
}

module "key_vault" {
  count               = var.enable_key_vault ? 1 : 0
  source              = "../../modules/key-vault"
  name                = coalesce(var.key_vault_name, substr("kv-${var.project}-${var.environment}-001", 0, 24))
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

module "key_vault_private_endpoint" {
  count  = var.enable_key_vault ? 1 : 0
  source = "../../modules/private-endpoint"

  name                           = "pe-${var.project}-${var.environment}-kv"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.spoke.name
  subnet_id                      = module.spoke_network.subnet_ids["snet-private"]
  private_connection_resource_id = module.key_vault[0].id
  subresource_names              = ["vault"]
  private_dns_zone_ids           = [azurerm_private_dns_zone.key_vault[0].id]
  tags                           = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.key_vault]
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

output "aks_name" {
  value = var.enable_aks ? module.aks[0].name : null
}

output "key_vault_uri" {
  value = var.enable_key_vault ? module.key_vault[0].vault_uri : null
}

output "key_vault_private_endpoint_ip" {
  value = var.enable_key_vault ? module.key_vault_private_endpoint[0].private_ip_addresses : null
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
