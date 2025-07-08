module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = local.location
  cache_results = true
  vm_filters = {
    cpu_architecture_type = "x64"
    min_vcpus             = local.vm_sku.cpus
    max_vcpus             = local.vm_sku.cpus
    min_memory_gb         = local.vm_sku.memory_gb
    max_memory_gb         = local.vm_sku.memory_gb
    # encryption_at_host_supported   = true
    # accelerated_networking_enabled = true
    premium_io_supported = true
    location_zone        = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}


module "windows_vm" {
  source           = "Azure/avm-res-compute-virtualmachine/azurerm"
  version          = "0.19.3"
  enable_telemetry = false
  # priority         = "Spot"
  # eviction_policy  = "Delete"

  os_type                = "Windows"
  sku_size               = module.vm_sku.sku
  # sku_size               = "Standard_B2s_v2"
  source_image_reference = local.vm_sku.vm_image
  license_type           = "Windows_Server"

  resource_group_name = module.resource_group.name
  location            = local.location
  name                = module.naming.virtual_machine.name_unique
  zone                = random_integer.zone_index.result

  encryption_at_host_enabled = false

  os_disk = {
    # name                      = module.naming.os_disk.name_unique
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = local.vm_sku.disk_size_gb
    # write_accelerator_enabled = true
  }

  managed_identities = {
    system_assigned = true
    # user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = module.virtual_network.subnets["subnet1"].resource_id
          create_public_ip_address      = true
          public_ip_address_name        = module.naming.public_ip.name_unique
        }
      }
      network_security_groups = {
        network_security_group_1 = {
          network_security_group_resource_id = azurerm_network_security_group.remote.id
        }
      }
    }
  }

  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = true
    }
  }

custom_data = base64encode(<<-CD
  # Install Chocolatey
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

  # Install Apps with Chocolatey
  choco install -y vscode git 7zip

  # Disable Microsoft Edge first run page
  $hideFirstRunExperience = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
  if (-not (Test-Path $hideFirstRunExperience)) {
    New-Item -Path $hideFirstRunExperience -Force
  }
  Set-ItemProperty -Path $hideFirstRunExperience -Name "HideFirstRunExperience" -Value 1 -Type DWord

  # Disable Server Manager startup
  Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
  CD
  )

extensions = {
  config_vm = {
    name                        = "CustomScriptExtension"
    failure_suppression_enabled = false
    publisher                   = "Microsoft.Compute"
    type                        = "CustomScriptExtension"
    type_handler_version        = "1.10"

    settings = jsonencode(
      {
        commandToExecute = "move c:\\AzureData\\CustomData.bin c:\\AzureData\\vm_config.ps1 && powershell.exe -ExecutionPolicy Unrestricted -File c:\\AzureData\\vm_config.ps1 > C:\\AzureData\\vm_config.log"
      }
    )

  }
}

  # run_commands = {
  #   install_chocolatey = {
  #     location = local.location
  #     name     = "install-chocolatey"
  #     script_source = {
  #       script = "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
  #     }
  #   }
  # }
  #   data_disk_managed_disks = {
  #     disk1 = {
  #       name                 = "${module.naming.managed_disk.name_unique}-lun0"
  #       storage_account_type = "Premium_LRS"
  #       lun                  = 0
  #       caching              = "ReadWrite"
  #       disk_size_gb         = 32
  #     }
  #   }


}
