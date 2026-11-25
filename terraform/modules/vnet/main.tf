resource "azurerm_virtual_network" "this" {
 name=var.name
 address_space=["10.0.0.0/16"]
 location="Central India"
 resource_group_name="rg-placeholder"
}
