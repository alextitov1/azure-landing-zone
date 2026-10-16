locals {
  location = "newzealandnorth"

  deployment_suffix = ["aks01"]
  kubernetes_version = "1.32.9"

  vnet_address_space = ["10.10.0.0/16"]

  aks_admin_group =  "6846f4d3-4290-4005-9dac-f912217875bd" # sg-k8sadmin-clickops-01

  #   vm_sku = {
  #     cpus         = 2
  #     memory_gb    = 4
  #     disk_size_gb = 128
  #     vm_image = {
  #       publisher = "MicrosoftWindowsServer"
  #       offer     = "WindowsServer"
  #       sku       = "2022-datacenter-g2"
  #       version   = "latest"
  #     }
  #   }

}

# resource "azurerm_role_assignment" "aks2-role-assignment" {
#   scope                = "/subscriptions/b63ed8a5-399c-4375-9365-9c5edb7deab7/resourceGroups/rg-aks01"
#   role_definition_name = "Reader"
#   principal_type       = "Group"
#   principal_id         = local.aks_admin_group
# }

data "azurerm_client_config" "current" {}

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

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  availability_zones_filter = true
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.location].zones)
  min = 1
}
