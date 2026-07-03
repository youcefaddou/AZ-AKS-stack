resource "azurerm_lb" "internal" {
  name                = "lb-backend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "backend-pool"
}

# On rattache les 2 VMs backend au pool du load balancer
resource "azurerm_network_interface_backend_address_pool_association" "backend" {
  count                   = 1
  network_interface_id    = azurerm_network_interface.backend[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id
}

resource "azurerm_lb_rule" "api" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "api"
  protocol                       = "Tcp"
  frontend_port                  = 3000
  backend_port                   = 3000
  frontend_ip_configuration_name = "internal"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend.id]
}