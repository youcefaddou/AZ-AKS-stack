resource "azurerm_network_interface" "backend" {
  count               = 1
  name                = "nic-backend-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "backend" {
  count               = 1
  name                = "vm-backend-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2ats_v2"
  admin_username      = "azureuser"
  zone                = "3"
  vtpm_enabled        = true
  secure_boot_enabled = true

  network_interface_ids = [
    azurerm_network_interface.backend[count.index].id
  ]

  custom_data = base64encode(templatefile("${path.module}/scripts/install-docker.sh", {
    admin_username = "azureuser"
  }))

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("./cloud-computing-tp.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "debian"
    offer     = "debian-12"
    sku       = "12-gen2"
    version   = "latest"
  }
}