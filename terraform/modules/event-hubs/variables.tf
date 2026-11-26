variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku" {
  type    = string
  default = "Standard"
}
variable "capacity" {
  type    = number
  default = 1
}
variable "event_hub_name" {
  type    = string
  default = "events"
}
variable "partition_count" {
  type    = number
  default = 2
}
variable "message_retention" {
  type    = number
  default = 1
}
variable "local_authentication_enabled" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
