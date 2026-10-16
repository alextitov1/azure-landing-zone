# Lab hub-and-spoke network, from ../config/network.yaml. Address space comes from Azure Virtual Network
# Manager IPAM pools: a root pool with a hub pool and a spokes pool below it.

locals {
  config          = yamldecode(file("${path.module}/../config/network.yaml"))
  subscription_id = "/subscriptions/${local.config.subscription_id}"
  location        = local.config.location

  # "<spoke>/<subnet>" => NSG workload, e.g. "workload/snet-app" => "workload-app"
  spoke_subnets = merge([
    for spoke, s in local.config.spokes : {
      for subnet in keys(s.subnets) : "${spoke}/${subnet}" => "${spoke}-${trimprefix(subnet, "snet-")}"
    }
  ]...)

  # A spoke subnet is a prefix length, or an object with prefix_length and consumers (principals that may join it)
  spokes = {
    for spoke, s in local.config.spokes : spoke => merge(s, {
      subnets = {
        for name, v in s.subnets : name => {
          prefix_length = try(v.prefix_length, v)
          consumers     = try([for c in v.consumers : c], [])
        }
      }
    })
  }
  consumers = flatten([for spoke, s in local.spokes : [for subnet in values(s.subnets) : subnet.consumers]])

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
  workloads = toset(concat(["connectivity", "hub", "root", "spokes"], keys(local.config.spokes), values(local.spoke_subnets)))
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

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = module.naming["connectivity"].names.resource_group.name
  location         = local.location
  enable_telemetry = false
}

# For IPAM. azurerm requires at least one feature, so Connectivity is enabled, but no network groups or
# connectivity configurations are created.
module "network_manager" {
  source  = "Azure/avm-res-network-networkmanager/azurerm"
  version = "0.3.0"

  name                           = module.naming["connectivity"].names.network_manager.name
  resource_group_name            = module.resource_group.name
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

module "hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.3"

  name             = module.naming["hub"].names.virtual_network.name
  parent_id        = module.resource_group.resource_id
  location         = local.location
  enable_telemetry = false

  ipam_pools = [{ id = azapi_resource.ipam["hub"].id, prefix_length = local.config.hub.prefix_length }]
  subnets = {
    for name, prefix_length in local.config.hub.subnets : name => {
      name       = name
      ipam_pools = [{ pool_id = azapi_resource.ipam["hub"].id, prefix_length = prefix_length }]
    }
  }
}

module "nsg" {
  source   = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version  = "0.6.0"
  for_each = local.spoke_subnets

  name             = module.naming[each.value].names.network_security_group.name
  parent_id        = module.resource_group.resource_id
  location         = local.location
  enable_telemetry = false
}

# Principals named in subnet consumers, as in ESLZ/subscriptions: group (display name), user (user principal
# name) or service_principal (display name). principal_id with principal_type skips the lookup.
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
}

module "spoke" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.22.3"
  for_each = local.spokes

  name             = module.naming[each.key].names.virtual_network.name
  parent_id        = module.resource_group.resource_id
  location         = local.location
  enable_telemetry = false

  ipam_pools = [{ id = azapi_resource.ipam["spokes"].id, prefix_length = each.value.prefix_length }]
  subnets = {
    for name, subnet in each.value.subnets : name => {
      name                   = name
      ipam_pools             = [{ pool_id = azapi_resource.ipam["spokes"].id, prefix_length = subnet.prefix_length }]
      network_security_group = { id = module.nsg["${each.key}/${name}"].resource_id }

      # Join (NICs, private endpoints) for each consumer, on this subnet only
      role_assignments = {
        for c in subnet.consumers : try("group/${c.group}", "user/${c.user}", "service_principal/${c.service_principal}", c.principal_id) => {
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
