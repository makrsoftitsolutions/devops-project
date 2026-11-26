variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}
variable "subnet_id" {
  type = string
}

variable "identity_id" {
  type = string
}

variable "system_node_count" {
  type    = number
  default = 1
}
variable "system_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}
variable "user_node_pool_name" {
  description = "Name for the Linux user node pool (1-12 lowercase alphanumeric characters)."
  type        = string
  default     = "usernodepl1"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,11}$", var.user_node_pool_name))
    error_message = "Linux AKS node pool names must start with a lowercase letter and contain at most 12 lowercase alphanumeric characters."
  }
}
variable "user_node_pool_min_count" {
  type    = number
  default = 2

  validation {
    condition     = var.user_node_pool_min_count >= 1
    error_message = "The user node pool minimum must be at least one node."
  }
}
variable "user_node_pool_max_count" {
  type    = number
  default = 3

  validation {
    condition     = var.user_node_pool_max_count >= var.user_node_pool_min_count
    error_message = "The user node pool maximum must be greater than or equal to its minimum."
  }
}
variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
