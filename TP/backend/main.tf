resource "azurerm_resource_group" "rg" {
name = "rg-b3-vm"
location = var.location
}
resource "azurerm_virtual_network" "vnet" {
name = "vnet-b3"
resource_group_name = azurerm_resource_group.rg.name
location = azurerm_resource_group.rg.location
address_space = ["10.10.0.0/16"]
}
resource "azurerm_subnet" "frontend_subnet" {
  name                 = "subnet-frontend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "subnet-backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

# Subnet dédié à l'Application Gateway 
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.3.0/24"]
}