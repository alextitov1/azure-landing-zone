module "virtual_network" {
  enable_telemetry = false
  source           = "Azure/avm-res-network-virtualnetwork/azurerm"
  version          = "0.8.1"

  address_space       = local.vnet_address_space
  location            = local.location
  name                = module.naming.virtual_network.name
  resource_group_name = module.resource_group.name
  subnets = {
    "subnet1" = {
      name                            = "${module.naming.subnet.name}-subnet1"
      address_prefixes                = [cidrsubnet(local.vnet_address_space[0], 8, 0)]
      default_outbound_access_enabled = true
    }
    "subnet2" = {
      name             = "${module.naming.subnet.name}-subnet2"
      address_prefixes = [cidrsubnet(local.vnet_address_space[0], 8, 1)]
    }
  }
}

resource "azurerm_network_security_group" "remote" {
  location            = local.location
  name                = module.naming.network_security_group.name_unique
  resource_group_name = module.resource_group.name

  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "3389"
    direction                  = "Inbound"
    name                       = "RDPtcp01"
    priority                   = 151
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
  #   security_rule {
  #     access                     = "Allow"
  #     destination_address_prefix = "*"
  #     destination_port_range     = "22"
  #     direction                  = "Inbound"
  #     name                       = "SSH"
  #     priority                   = 152
  #     protocol                   = "Tcp"
  #     source_address_prefix      = "*"
  #     source_port_range          = "*"
  #   }
}