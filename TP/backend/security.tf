resource "azurerm_network_security_group" "frontend_nsg" {
  name                = "nsg-frontend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "frontend_nsg_link" {
  subnet_id                 = azurerm_subnet.frontend_subnet.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}
