output "id" {
  value = try(azurerm_resource_group.this.id, null)
}
