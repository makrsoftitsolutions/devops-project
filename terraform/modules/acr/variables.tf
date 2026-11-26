variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type    = string
  default = "Basic"
}

variable "public_network_access_enabled" {
  description = "Keep public access enabled when GitHub-hosted runners need to push images. Private endpoints require Premium SKU."
  type        = bool
  default     = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
