resource "azurerm_eventhub_namespace" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.capacity
  minimum_tls_version           = "1.2"
  local_authentication_enabled  = var.local_authentication_enabled
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_eventhub" "this" {
  name              = var.event_hub_name
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = var.partition_count
  message_retention = var.message_retention
}
