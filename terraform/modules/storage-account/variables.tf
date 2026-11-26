variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "replication_type" {
  type    = string
  default = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "Choose a supported Storage replication type."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
