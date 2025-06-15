module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = local.location
  cache_results = true
  vm_filters = {
    cpu_architecture_type = "x64"
    min_vcpus        = local.vm_sku.cpus
    max_vcpus        = local.vm_sku.cpus
    min_memory_gb = local.vm_sku.memory_gb
    max_memory_gb = local.vm_sku.memory_gb
    # encryption_at_host_supported   = true
    # accelerated_networking_enabled = true
    premium_io_supported = true
    location_zone        = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}


module "windows_vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.3"

  enable_telemetry           = false
  location                   = local.location
  name                       = module.naming.virtual_machine.name_unique
  encryption_at_host_enabled = false

  os_disk = {
    # name                      = module.naming.os_disk.name_unique
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = local.vm_sku.disk_size_gb
    # write_accelerator_enabled = true
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

  resource_group_name = module.resource_group.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = true
    }
  }
  #   data_disk_managed_disks = {
  #     disk1 = {
  #       name                 = "${module.naming.managed_disk.name_unique}-lun0"
  #       storage_account_type = "Premium_LRS"
  #       lun                  = 0
  #       caching              = "ReadWrite"
  #       disk_size_gb         = 32
  #     }
  #   }

  os_type  = "Windows"
  sku_size = module.vm_sku.sku
  source_image_reference = local.vm_sku.vm_image

}
