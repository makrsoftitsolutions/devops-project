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
  default     = null
  description = "AzureFirewallManagementSubnet ID when a separate management IP is enabled for forced tunneling."
}

variable "enable_management_ip" {
  type        = bool
  default     = false
  description = "Create the separate management public IP and management configuration for forced tunneling."
}

variable "tags" {
  type    = map(string)
  default = {}
}
