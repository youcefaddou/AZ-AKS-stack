output "kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}
