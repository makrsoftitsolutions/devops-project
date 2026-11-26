variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "retention_in_days" {
  type    = number
  default = 90
}
variable "sampling_percentage" {
  type    = number
  default = 100
}
variable "tags" {
  type    = map(string)
  default = {}
}
