output "waf_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "lb_private_ip" {
  value = azurerm_lb.internal.private_ip_address
}

output "frontend_private_ips" {
  value = azurerm_network_interface.frontend[*].private_ip_address
}

output "database_fqdn" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}
