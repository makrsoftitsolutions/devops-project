resource "azurerm_servicebus_namespace" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  minimum_tls_version           = "1.2"
  local_auth_enabled            = var.local_auth_enabled
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_servicebus_queue" "this" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.this.id
}
