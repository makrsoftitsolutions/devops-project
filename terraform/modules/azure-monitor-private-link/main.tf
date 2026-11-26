resource "azurerm_monitor_private_link_scope" "this" {
  name                  = var.name
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
  tags                  = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "this" {
  for_each = var.linked_resource_ids

  name                = "${var.name}-${each.key}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = each.value
}
