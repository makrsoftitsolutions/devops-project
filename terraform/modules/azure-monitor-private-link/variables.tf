variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "linked_resource_ids" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
