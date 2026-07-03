terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Les providers helm et kubernetes utilisent le kubeconfig généré par AKS.
# Ils dépendent implicitement du module aks via les data sources ci-dessous.
locals {
  kube_config = yamldecode(module.aks.kube_config)
}

provider "kubernetes" {
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster["certificate-authority-data"])
  token                  = local.kube_config.users[0].user.token
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster["certificate-authority-data"])
    token                  = local.kube_config.users[0].user.token
  }
}
