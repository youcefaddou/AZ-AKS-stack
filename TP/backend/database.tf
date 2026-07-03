variable "db_password" {
  type      = string
  sensitive = true
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = "psql-b3-tp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "17"

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768
  zone       = "2"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "vnet" {
  name             = "allow-vnet"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "10.10.0.0"
  end_ip_address   = "10.10.255.255"
}

# Authorise l'IP publique du NAT Gateway (trafic sortant des VMs)
resource "azurerm_postgresql_flexible_server_firewall_rule" "nat" {
  name             = "allow-nat-gateway"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = azurerm_public_ip.nat_ip.ip_address
  end_ip_address   = azurerm_public_ip.nat_ip.ip_address
}
