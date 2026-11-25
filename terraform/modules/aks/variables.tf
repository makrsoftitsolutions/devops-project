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
  type = string
  default = null
}
variable "subnet_id" {
  type = string
}
variable "identity_id" {
  type = string
}
variable "system_node_count" {
  type = number
  default = 1
}
variable "system_vm_size" {
  type = string
  default = "Standard_D2s_v5"
}
variable "admin_group_object_ids" {
  type = list(string)
  default = []
}
variable "log_analytics_workspace_id" {
  type = string
  default = null
}
variable "tags" { type = map(string) default = {} }
