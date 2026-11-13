# Hub-and-spoke network of ESLZ/connectivity, from its config/network.yaml: VNets and subnets get their address
# space from Azure Virtual Network Manager IPAM pools (a root pool with a hub pool and a spokes pool below it).
# Private and public DNS zones are in dns.tf.

locals {
  config            = var.config
  subscription_id   = "/subscriptions/${local.config.subscription_id}"
  location          = local.config.location
  resource_group_id = data.azapi_resource.resource_group.id

  # Azure allows no NSG on these subnets
  subnets_without_nsg = ["GatewaySubnet", "AzureFirewallSubnet", "AzureFirewallManagementSubnet", "RouteServerSubnet"]

  # "hub" and the spokes, each with its subnets. A subnet is a prefix length, or an object with prefix_length,
  # consumers (principals that may join it) and security_rules of its NSG.
  vnets = merge({ hub = local.config.hub }, local.config.spokes)
  subnets = {
    for vnet, v in local.vnets : vnet => {
      for name, s in v.subnets : name => {
        prefix_length  = try(s.prefix_length, s)
        consumers      = try([for c in s.consumers : c], [])
        security_rules = try([for r in s.security_rules : r], [])
        nsg_workload   = contains(local.subnets_without_nsg, name) ? null : "${vnet}-${trimprefix(name, "snet-")}"
      }
    }
  }

  # "<vnet>/<subnet>" => subnet, for the subnets with an NSG, e.g. "cortex/snet-aks" (NSG workload "cortex-aks")
  nsg_subnets = merge([
    for vnet, subnets in local.subnets : { for name, s in subnets : "${vnet}/${name}" => s if s.nsg_workload != null }
  ]...)
  consumers = concat(
    flatten([for subnets in values(local.subnets) : [for s in values(subnets) : s.consumers]]),
    flatten([for z in values(local.public_dns_zones) : concat(z.consumers, z.readers)]),
  )

  # Windows 365 Network User: the narrowest built-in role with Microsoft.Network/virtualNetworks/subnets/join/action
  # (virtualNetworks/read, subnets/read, usages/read and subnets/join/action, nothing else). Connectivity cannot
  # create a custom role: Contributor and RBAC Administrator have no roleDefinitions/write.
  subnet_join_role = "${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7eabc9a4-85f7-4f71-b8ab-75daaccc1033"

  # "<spoke>/<reservation>" => prefix length, e.g. "cortex/aks-services" => 24
  spoke_reservations = merge([
    for spoke, s in local.config.spokes : {
      for name, prefix_length in try(s.reservations, {}) : "${spoke}/${name}" => prefix_length
    }
  ]...)

  # The workload part of each name
  workloads = toset(concat(
    ["connectivity", "hub", "root", "spokes"], keys(local.config.spokes), [for s in values(local.nsg_subnets) : s.nsg_workload],
  ))
}

# Created by subscription vending in ESLZ/governance, which grants this workspace its roles on it
data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.config.resource_group
  parent_id = local.subscription_id
}

# Names: <type>-<workload>-<env>-<region>-<nn>, see ESLZ/README.md. The type is the CAF abbreviation from
# the naming catalog, with the corrections in naming-overrides.json.
module "naming" {
  source   = "Azure/avm-utl-naming/azure"
  version  = "0.2.0"
  for_each = local.workloads

  suffix               = [each.key, local.config.environment, local.config.region_code]
  instance             = local.config.instance
  instance_format      = "%02d"
  unique_length        = 0
  custom_override_file = "${path.module}/naming-overrides.json"
}

# For IPAM. azurerm requires at least one feature, so Connectivity is enabled, but no network groups or
# connectivity configurations are created.
module "network_manager" {
  source  = "Azure/avm-res-network-networkmanager/azurerm"
  version = "0.3.0"

  name                           = module.naming["connectivity"].names.network_manager.name
  resource_group_name            = local.config.resource_group
  location                       = local.location
  network_manager_scope          = { subscription_ids = [local.subscription_id] }
  network_manager_scope_accesses = ["Connectivity"]
  enable_telemetry               = false
}

resource "azapi_resource" "ipam_root" {
  type      = "Microsoft.Network/networkManagers/ipamPools@2024-07-01"
  parent_id = module.network_manager.resource_id
  name      = module.naming["root"].names.network_manager_ipam_pool.name
  location  = local.location
  body = {
    properties = {
      addressPrefixes = [local.config.ipam.root]
      displayName     = "Root"
    }
  }

  # Deletion fails until the child pools and VNets have released their allocations
  retry = {
    error_message_regex = ["BadRequest", "Ipam pool.*has Azure resources associated"]
  }
}

resource "azapi_resource" "ipam" {
  for_each = { hub = local.config.ipam.hub, spokes = local.config.ipam.spokes }

  type      = "Microsoft.Network/networkManagers/ipamPools@2024-07-01"
  parent_id = module.network_manager.resource_id
  name      = module.naming[each.key].names.network_manager_ipam_pool.name
  location  = local.location
  body = {
    properties = {
      addressPrefixes = [each.value]
      parentPoolName  = azapi_resource.ipam_root.name
      displayName     = title(each.key)
    }
  }

  retry = {
    error_message_regex = ["BadRequest", "Ipam pool.*has Azure resources associated"]
  }
}

# Ranges a spoke uses outside its VNet, such as the service CIDR of an AKS cluster with Azure CNI Overlay.
# IPAM allocates them like a VNet, so VNets never overlap them.
resource "azapi_resource" "reservation" {
  for_each = local.spoke_reservations

  type      = "Microsoft.Network/networkManagers/ipamPools/staticCidrs@2024-07-01"
  parent_id = azapi_resource.ipam["spokes"].id
  name      = replace(each.key, "/", "-")
  body = {
    properties = {
      numberOfIPAddressesToAllocate = tostring(pow(2, 32 - each.value))
      description                   = "Reserved for ${each.key}, used outside its VNet"
    }
  }
  response_export_values = ["properties.addressPrefixes"]
}

module "nsg" {
  source   = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version  = "0.6.0"
  for_each = local.nsg_subnets

  name             = module.naming[each.value.nsg_workload].names.network_security_group.name
  parent_id        = local.resource_group_id
  location         = local.location
  enable_telemetry = false

  security_rules = {
    for r in each.value.security_rules : r.name => {
      name                         = r.name
      priority                     = r.priority
      direction                    = r.direction
      access                       = r.access
      protocol                     = r.protocol
      description                  = try(r.description, null)
      source_address_prefix        = try(r.source_address_prefix, null)
      source_address_prefixes      = try(r.source_address_prefixes, null)
      source_port_range            = try(r.source_port_range, null)
      source_port_ranges           = try(r.source_port_ranges, null)
      destination_address_prefix   = try(r.destination_address_prefix, null)
      destination_address_prefixes = try(r.destination_address_prefixes, null)
      destination_port_range       = try(r.destination_port_range, null)
      destination_port_ranges      = try(r.destination_port_ranges, null)
    }
  }
}

# Principals named in subnet consumers and in public DNS zone consumers and readers, as in ESLZ/governance/subscriptions: group (display name), user (user
# principal name) or service_principal (display name). principal_id with principal_type skips the lookup.
data "azuread_group" "this" {
  for_each = toset([for c in local.consumers : c.group if try(c.group, null) != null])

  display_name     = each.key
  security_enabled = true
}

data "azuread_user" "this" {
  for_each = toset([for c in local.consumers : c.user if try(c.user, null) != null])

  user_principal_name = each.key
}

data "azuread_service_principal" "this" {
  for_each = toset([for c in local.consumers : c.service_principal if try(c.service_principal, null) != null])

  display_name = each.key
}

locals {
  principals = merge(
    { for name, g in data.azuread_group.this : "group/${name}" => { id = g.object_id, type = "Group" } },
    { for upn, u in data.azuread_user.this : "user/${upn}" => { id = u.object_id, type = "User" } },
    { for name, sp in data.azuread_service_principal.this : "service_principal/${name}" => { id = sp.object_id, type = "ServicePrincipal" } },
  )

  # Subnets of each VNet as the VNet module takes them: address space from the hub or spokes pool, the NSG, and
  # join for each consumer, on that subnet only
  vnet_subnets = {
    for vnet, subnets in local.subnets : vnet => {
      for name, s in subnets : name => {
        name                   = name
        ipam_pools             = [{ pool_id = azapi_resource.ipam[vnet == "hub" ? "hub" : "spokes"].id, prefix_length = s.prefix_length }]
        network_security_group = s.nsg_workload == null ? null : { id = module.nsg["${vnet}/${name}"].resource_id }
        role_assignments = {
          for c in s.consumers : try("group/${c.group}", "user/${c.user}", "service_principal/${c.service_principal}", c.principal_id) => {
            role_definition_id_or_name = local.subnet_join_role
            principal_id = try(
              local.principals["group/${c.group}"].id, local.principals["user/${c.user}"].id,
              local.principals["service_principal/${c.service_principal}"].id, c.principal_id,
            )
            principal_type = try(
              local.principals["group/${c.group}"].type, local.principals["user/${c.user}"].type,
              local.principals["service_principal/${c.service_principal}"].type, c.principal_type,
            )
          }
        }
      }
    }
  }
}

module "hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.3"

  name             = module.naming["hub"].names.virtual_network.name
  parent_id        = local.resource_group_id
  location         = local.location
  enable_telemetry = false

  ipam_pools = [{ id = azapi_resource.ipam["hub"].id, prefix_length = local.config.hub.prefix_length }]
  subnets    = local.vnet_subnets["hub"]
}

module "spoke" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.22.3"
  for_each = local.config.spokes

  name             = module.naming[each.key].names.virtual_network.name
  parent_id        = local.resource_group_id
  location         = local.location
  enable_telemetry = false

  ipam_pools = [{ id = azapi_resource.ipam["spokes"].id, prefix_length = each.value.prefix_length }]
  subnets    = local.vnet_subnets[each.key]

  # Spoke to hub, and hub to spoke
  peerings = {
    hub = {
      name                               = "peer-${each.key}-to-hub"
      remote_virtual_network_resource_id = module.hub.resource_id
      create_reverse_peering             = true
      reverse_name                       = "peer-hub-to-${each.key}"
    }
  }
}
