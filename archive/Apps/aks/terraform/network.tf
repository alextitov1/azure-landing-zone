module "virtual_network" {
  enable_telemetry = false
  source           = "Azure/avm-res-network-virtualnetwork/azurerm"
  version          = "0.8.1"

  address_space       = local.vnet_address_space
  location            = local.location
  name                = module.naming.virtual_network.name
  resource_group_name = module.resource_group.name
  subnets = {
    "subnet" = {
      name                            = "${module.naming.subnet.name}-subnet"
      address_prefixes                = [cidrsubnet(local.vnet_address_space[0], 8, 0)]
      default_outbound_access_enabled = true
    }
    "private_link_subnet" = {
      name             = "${module.naming.subnet.name}-private_link_subnet"
      address_prefixes = [cidrsubnet(local.vnet_address_space[0], 8, 1)]
    }
  }
}