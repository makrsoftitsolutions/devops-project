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

variable "backend_fqdn" {
  type    = string
  default = null
}

variable "zones" {
  description = "Availability zones for the gateway; use an empty list for regional placement."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
