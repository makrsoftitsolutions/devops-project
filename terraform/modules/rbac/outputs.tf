output "ids" {
  description = "Role assignment IDs keyed by the assignment map key."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}
