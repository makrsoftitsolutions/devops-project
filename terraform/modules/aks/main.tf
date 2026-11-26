resource "azurerm_kubernetes_cluster" "this" {
  name                              = var.name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  dns_prefix                        = var.dns_prefix
  kubernetes_version                = var.kubernetes_version
  sku_tier                          = "Free"
  private_cluster_enabled           = true
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = var.system_node_count
    vm_size        = var.system_vm_size
    vnet_subnet_id = var.subnet_id
    type           = "VirtualMachineScaleSets"
    os_sku         = "AzureLinux"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = length(var.admin_group_object_ids) > 0 ? [1] : []
    content {
      azure_rbac_enabled     = true
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags

  lifecycle {
    # Azure adds default upgrade settings to the node pool even when they are
    # omitted from configuration. Ignore that service-managed block to avoid
    # an in-place AKS update on every plan/apply.
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.enable_user_node_pool ? 1 : 0

  name                  = var.user_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_pool_vm_size
  mode                  = "User"
  os_type               = "Linux"
  os_sku                = "AzureLinux"
  vnet_subnet_id        = var.subnet_id

  auto_scaling_enabled = true
  min_count            = var.user_node_pool_min_count
  max_count            = var.user_node_pool_max_count

  tags = var.tags
}
