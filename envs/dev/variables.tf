variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "cluster_name" {
  type    = string
  default = "aks-tp"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}
