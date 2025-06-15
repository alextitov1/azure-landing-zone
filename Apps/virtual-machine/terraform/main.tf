locals {
  location          = "newzealandnorth"
  
  deployment_suffix = ["vm01"]

  vnet_address_space = ["10.5.0.0/16"]

  vm_sku = {
    cpus = 2
    memory_gb = 4
    disk_size_gb = 128
    vm_image = {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2022-datacenter-g2"
        version   = "latest"
    }
  }

}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"

  suffix = local.deployment_suffix
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.1"

  location         = local.location
  name             = module.naming.resource_group.name
  enable_telemetry = false
}

resource "azurerm_dns_a_record" "vm01-public-dns-name" {
  name                = "temp-windows-vm"
  zone_name           = "4esnok.su"
  resource_group_name = "rg-public-dns-01"
  ttl                 = 300
  records             = [module.windows_vm.public_ips["network_interface_1-ip_configuration_1"].ip_address]
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  availability_zones_filter = true
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.location].zones)
  min = 1
}
