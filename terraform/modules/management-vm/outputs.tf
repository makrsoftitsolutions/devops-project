output "vm_id" {
  description = "Management VM resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Management VM name."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Management VM private IP address."
  value       = azurerm_network_interface.this.private_ip_address
}

output "principal_id" {
  description = "System-assigned managed identity principal ID."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}