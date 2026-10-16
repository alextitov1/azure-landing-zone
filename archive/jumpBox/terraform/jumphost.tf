
resource "azurerm_subnet" "internal" {
  name                 = "internal01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["192.168.1.0/27"]
}

resource "azurerm_network_interface" "jumphost-nic01" {
  name                = "jumphost-nic01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumphost" {
  name                = "jumphost01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D4_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  provision_vm_agent  = true
  network_interface_ids = [
    azurerm_network_interface.jumphost-nic01.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "post-provisioning" {
  name                 = "postvmprovisioning"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  virtual_machine_id   = azurerm_windows_virtual_machine.jumphost.id
  settings             = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -Command \" Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/alextitov1/azure/main/scripts/jumpbox-postprov.ps1')) \""
  }
SETTINGS
}
