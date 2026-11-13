# Lab hub-and-spoke network and private DNS zones, from ../config/network.yaml (README.md).

locals {
  config = yamldecode(file("${path.module}/../config/network.yaml"))
}

module "network" {
  source = "../../../modules/azure-connectivity"

  config = local.config
}
