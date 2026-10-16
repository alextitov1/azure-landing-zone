# Container registry, configured by `registry` in ../config/dev.yaml. The AKS nodes pull with the kubelet identity,
# which has AcrPull on the resource group (ESLZ/subscriptions); members of sg-t2-az-cortex-contributor push.

locals {
  registry = local.config.registry
}

module "registry" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.8.0"

  name                = module.naming[local.config.workload].names.registry.name
  resource_group_name = local.config.resource_group
  location            = local.config.location
  tags                = local.tags
  enable_telemetry    = false

  sku                           = local.registry.sku
  public_network_access_enabled = local.registry.public_network_access
  zone_redundancy_enabled       = local.registry.zone_redundancy
  retention_policy_in_days      = local.registry.retention_days
  admin_enabled                 = local.registry.admin_user
  anonymous_pull_enabled        = local.registry.anonymous_pull
}
