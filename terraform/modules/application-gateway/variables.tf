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
  type = string
  default = null
}

variable "tags" {
  type = map(string)
  default = {}
}
