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

# Public DNS zones (CAF: owned by connectivity). Workload pipelines have no rights on this resource group, so a zone
# names the principals that may write its records (consumers) and the plan identities that refresh them (readers).
locals {
  public_dns_zones = try({
    for name, z in local.config.public_dns_zones : name => {
      consumers = try([for c in z.consumers : c], [])
      readers   = try([for c in z.readers : c], [])
    }
  }, {})

  # "<zone>|<role>|<principal>" => role assignment on the zone
  public_dns_zone_access = merge([
    for zone, z in local.public_dns_zones : {
      for a in concat(
        [for c in z.consumers : { role = "DNS Zone Contributor", principal = c }],
        [for c in z.readers : { role = "Reader", principal = c }],
        ) : join("|", [
          zone, a.role,
          try("group/${a.principal.group}", "user/${a.principal.user}", "service_principal/${a.principal.service_principal}", a.principal.principal_id),
        ]) => {
        zone = zone
        role = a.role
        principal_id = try(
          local.principals["group/${a.principal.group}"].id, local.principals["user/${a.principal.user}"].id,
          local.principals["service_principal/${a.principal.service_principal}"].id, a.principal.principal_id,
        )
        principal_type = try(
          local.principals["group/${a.principal.group}"].type, local.principals["user/${a.principal.user}"].type,
          local.principals["service_principal/${a.principal.service_principal}"].type, a.principal.principal_type,
        )
      }
    }
  ]...)
}

module "public_dns_zone" {
  source   = "Azure/avm-res-network-dnszone/azurerm"
  version  = "0.2.1"
  for_each = local.public_dns_zones

  name                = each.key
  resource_group_name = local.config.resource_group
  enable_telemetry    = false
}

# The zone module takes no role assignments
resource "azurerm_role_assignment" "public_dns_zone" {
  for_each = local.public_dns_zone_access

  scope                = module.public_dns_zone[each.value.zone].resource_id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}
