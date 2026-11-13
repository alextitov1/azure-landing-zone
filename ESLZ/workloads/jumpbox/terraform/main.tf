# Workload jumpbox (tier 2): a Windows VM in the hub. Configuration in ../config/dev.yaml; the subnet comes from the
# outputs of the connectivity workspace.

locals {
  config = yamldecode(file("${path.module}/../config/dev.yaml"))
}

# Outputs of ESLZ/connectivity: subnets = { "<vnet>/<subnet>" = <subnet ID> } and public_dns_zones by zone name
data "tfe_outputs" "connectivity" {
  organization = "4esnok"
  workspace    = "4esnok_vs_azure_networking_r1"
}

module "jumpbox" {
  source = "../../../../modules/azure-windows-jumpbox"

  config              = local.config.jumpbox
  name_suffix         = [local.config.workload, local.config.environment, local.config.region_code]
  instance            = local.config.instance
  resource_group_name = local.config.resource_group
  location            = local.config.location
  subnet_id           = data.tfe_outputs.connectivity.nonsensitive_values.subnets[local.config.subnet]
  tags                = try(local.config.tags, null)

  dns_record = try(local.config.dns, null) == null ? null : {
    name                = local.config.dns.name
    zone_name           = local.config.dns.zone
    resource_group_name = data.tfe_outputs.connectivity.nonsensitive_values.public_dns_zones[local.config.dns.zone].resource_group_name
    ttl                 = local.config.dns.ttl
  }
}
