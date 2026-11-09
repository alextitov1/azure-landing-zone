# Container registry, configured by `registry` in ../config/dev.yaml. The AKS nodes pull with the kubelet identity,
# which has AcrPull on the resource group (ESLZ/governance), through the private endpoint; members of
# sg-az-cortex-contributor-t2 push.

locals {
  registry = local.config.registry
}

module "registry" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.8.0"

  name                = module.naming[local.config.workload].names.registry.name
  resource_group_name = local.config.resource_group
  location            = local.config.location
  tags                = merge(local.tags, try(local.registry.tags, {}))
  enable_telemetry    = false

  sku                           = local.registry.sku
  public_network_access_enabled = local.registry.public_network_access
  network_rule_bypass_option    = try(local.registry.trusted_services, false) ? "AzureServices" : "None"
  zone_redundancy_enabled       = local.registry.zone_redundancy
  retention_policy_in_days      = local.registry.retention_days
  admin_enabled                 = local.registry.admin_user
  anonymous_pull_enabled        = local.registry.anonymous_pull

  private_endpoints = try(local.registry.private_endpoint_subnet, null) == null ? {} : {
    registry = {
      name                   = "pep-${module.naming[local.config.workload].names.registry.name}"
      network_interface_name = "nic-pep-${module.naming[local.config.workload].names.registry.name}"
      subnet_resource_id     = local.connectivity.subnets[local.registry.private_endpoint_subnet]
    }
  }
  # Azure Policy adds the DNS zone group (Deploy-PrivateLink-DNS, ESLZ/governance): this pipeline has no rights on
  # the central zones in the connectivity resource group
  private_endpoints_manage_dns_zone_group = false
}
