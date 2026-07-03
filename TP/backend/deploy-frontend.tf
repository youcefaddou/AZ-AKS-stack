resource "azurerm_virtual_machine_extension" "frontend_app" {
  count                = length(azurerm_linux_virtual_machine.frontend)
  name                 = "deploy-web"
  virtual_machine_id   = azurerm_linux_virtual_machine.frontend[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    script = base64encode(templatefile("${path.module}/scripts/frontend.sh", {}))
  })
}