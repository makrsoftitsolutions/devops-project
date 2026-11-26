variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "management_subnet_id" {
  type        = string
  description = "AzureFirewallManagementSubnet ID required by the Basic SKU."
}

variable "tags" {
  type    = map(string)
  default = {}
}
