module "network" {
  source              = "../../modules/network"
  resource_group_name = "rg-tp-iac"
  location            = var.location
}

module "aks" {
  source              = "../../modules/aks"
  cluster_name        = var.cluster_name
  location            = var.location
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_id
  node_count          = var.node_count
  vm_size             = var.vm_size
}
