# Workload cortex (tier 2): an AKS cluster (aks.tf) and its container registry (registry.tf). Configuration in
# ../config/dev.yaml; platform IDs come from the outputs of the platform workspaces.

locals {
  config = yamldecode(file("${path.module}/../config/dev.yaml"))
  tags   = try(local.config.tags, {})
}

# Created and access-controlled by ESLZ/subscriptions
data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.config.resource_group
  parent_id = "/subscriptions/${local.config.subscription_id}"
}

# Outputs of ESLZ/connectivity: subnets = { "<vnet>/<subnet>" = <subnet ID> },
# reservations = { "<spoke>/<name>" = <address prefix> }, vnets, resource_group_id
data "tfe_outputs" "connectivity" {
  organization = "4esnok"
  workspace    = "4esnok_su_connectivity"
}

locals {
  resource_group_id = data.azapi_resource.resource_group.id
  connectivity      = data.tfe_outputs.connectivity.nonsensitive_values
  subnet_id         = local.connectivity.subnets[local.config.subnet]
}

# Names: <type>-<workload>-<env>-<region>-<nn>, see ESLZ/README.md. "<workload>-aksnodes" names the node resource
# group of the AKS cluster.
module "naming" {
  source   = "Azure/avm-utl-naming/azure"
  version  = "0.2.0"
  for_each = toset([local.config.workload, "${local.config.workload}-aksnodes"])

  suffix          = [each.key, local.config.environment, local.config.region_code]
  instance        = local.config.instance
  instance_format = "%02d"
  unique_length   = 0
}
