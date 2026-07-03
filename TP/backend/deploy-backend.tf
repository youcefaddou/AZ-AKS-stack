resource "azurerm_virtual_machine_extension" "backend_app" {
  count                = length(azurerm_linux_virtual_machine.backend)
  name                 = "deploy-api"
  virtual_machine_id   = azurerm_linux_virtual_machine.backend[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    script = base64encode(templatefile("${path.module}/scripts/backend.sh", {
      db_fqdn     = azurerm_postgresql_flexible_server.db.fqdn
      db_password = var.db_password
    }))
  })
}