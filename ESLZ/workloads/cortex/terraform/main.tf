# Workload cortex (tier 2). Configuration in ../config/dev.yaml; platform IDs come from the outputs of the
# platform workspaces. Nothing is deployed yet: the data sources below check that the workspace can read its
# resource group and the connectivity outputs.

locals {
  config = yamldecode(file("${path.module}/../config/dev.yaml"))
}

# Created and access-controlled by ESLZ/subscriptions
data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.config.resource_group
  parent_id = "/subscriptions/${local.config.subscription_id}"
}

# Outputs of ESLZ/connectivity: subnets = { "<vnet>/<subnet>" = <subnet ID> }, vnets, resource_group_id
data "tfe_outputs" "connectivity" {
  organization = "4esnok"
  workspace    = "4esnok_su_connectivity"
}

locals {
  resource_group_id = data.azapi_resource.resource_group.id
  subnet_id         = data.tfe_outputs.connectivity.nonsensitive_values.subnets[local.config.subnet]
}

# Workload resources go here, with Azure Verified Modules (https://azure.github.io/Azure-Verified-Modules/),
# parent_id = local.resource_group_id and, for anything in the network, subnet_id = local.subnet_id.
