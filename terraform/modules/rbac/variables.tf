variable "assignments" {
  description = "Role assignments to create, keyed by a stable Terraform name."
  type = map(object({
    scope                = string
    role_definition_name = string
    principal_id         = string
    principal_type       = optional(string, "ServicePrincipal")
  }))
  default = {}
}
