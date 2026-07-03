variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "aks_subnet_prefix" {
  type    = string
  default = "10.20.1.0/24"
}
