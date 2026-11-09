# Central private DNS zones for private endpoints (CAF: one zone per service, owned by connectivity). Each is linked
# to the hub and every spoke, which use Azure DNS, so they resolve private endpoints without a DNS server; a DNS
# Private Resolver in the hub is the next step once on-premises or VPN clients need the names. Azure Policy writes
# the records (Deploy-PrivateLink-DNS in ESLZ/governance/alz-lib), so landing zones need no rights on the zones.

locals {
  # VNet key ("hub" or a spoke) => resource ID and name
  vnet_links = merge(
    { hub = { id = module.hub.resource_id, name = module.naming["hub"].names.virtual_network.name } },
    { for spoke, m in module.spoke : spoke => { id = m.resource_id, name = module.naming[spoke].names.virtual_network.name } },
  )
}

module "private_dns_zone" {
  source   = "Azure/avm-res-network-privatednszone/azurerm"
  version  = "0.6.0"
  for_each = toset(try(local.config.private_dns_zones, []))

  domain_name      = each.key
  parent_id        = local.resource_group_id
  enable_telemetry = false

  virtual_network_links = {
    for vnet, link in local.vnet_links : vnet => {
      name               = link.name
      virtual_network_id = link.id
    }
  }
}
