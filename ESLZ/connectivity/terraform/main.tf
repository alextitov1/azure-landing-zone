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

module "spoke" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm"
  version  = "0.22.3"
  for_each = local.config.spokes

  name             = module.naming[each.key].names.virtual_network.name
  parent_id        = module.resource_group.resource_id
  location         = local.location
  enable_telemetry = false

  ipam_pools = [{ id = azapi_resource.ipam["spokes"].id, prefix_length = each.value.prefix_length }]
  subnets = {
    for name, prefix_length in each.value.subnets : name => {
      name                   = name
      ipam_pools             = [{ pool_id = azapi_resource.ipam["spokes"].id, prefix_length = prefix_length }]
      network_security_group = { id = module.nsg["${each.key}/${name}"].resource_id }
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
