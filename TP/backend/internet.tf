# IP publique pour la NAT Gateway
resource "azurerm_public_ip" "nat_ip" {
  name                = "pip-nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway
resource "azurerm_nat_gateway" "nat_gw" {
  name                    = "nat-backend"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

# Association IP publique <-> NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gw.id
  public_ip_address_id = azurerm_public_ip.nat_ip.id
}

# Association NAT Gateway <-> subnet backend (privé)
resource "azurerm_subnet_nat_gateway_association" "nat_backend_assoc" {
  subnet_id      = azurerm_subnet.backend_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gw.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_frontend_assoc" {
  subnet_id      = azurerm_subnet.frontend_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gw.id
}