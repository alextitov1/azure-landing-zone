# Lab hub-and-spoke network, private DNS zones and the jumpbox, from ../config/network.yaml (README.md).

locals {
  config  = yamldecode(file("${path.module}/../config/network.yaml"))
  jumpbox = try(local.config.jumpbox, { enabled = false })
}

module "network" {
  source = "../../../modules/azure-connectivity"

  config = local.config
}

module "jumpbox" {
  source = "../../../modules/azure-windows-jumpbox"
  count  = local.jumpbox.enabled ? 1 : 0

  config              = local.jumpbox
  name_suffix         = ["jumpbox", local.config.environment, local.config.region_code]
  instance            = local.config.instance
  resource_group_name = local.config.resource_group
  location            = local.config.location
  subnet_id           = module.network.subnets[local.jumpbox.subnet]
  tags                = try(local.jumpbox.tags, null)
}
