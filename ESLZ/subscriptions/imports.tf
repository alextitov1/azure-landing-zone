# Reads each subscription (Reader is enough), to adopt resource groups and budgets that the YAML declares
# and that already exist, and to list what exists but is not declared yet (outputs.tf). Import blocks for
# objects already in the state are skipped, so these stay in place.

data "azapi_resource" "subscription" {
  for_each = local.config

  type                   = "Microsoft.Resources/subscriptions@2022-12-01"
  resource_id            = "/subscriptions/${each.value.subscription_id}"
  response_export_values = ["displayName"]
}

data "azapi_resource_list" "resource_groups" {
  for_each = local.config

  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  parent_id              = "/subscriptions/${each.value.subscription_id}"
  response_export_values = { groups = "value[].{name: name, id: id, location: location}" }
}

data "azapi_resource_list" "budgets" {
  for_each = { for sub, c in local.config : sub => c if length(c.budgets) > 0 }

  type                   = "Microsoft.Consumption/budgets@2021-10-01"
  parent_id              = "/subscriptions/${each.value.subscription_id}"
  response_export_values = { budgets = "value[].{name: name, id: id}" }
}

locals {
  existing_resource_groups = {
    for sub, d in data.azapi_resource_list.resource_groups : sub => { for g in d.output.groups : g.name => g }
  }
}

import {
  for_each = merge([
    for sub, c in local.config : {
      for name in keys(c.resource_groups) :
      "${sub}/${name}" => { sub = sub, name = name, id = local.existing_resource_groups[sub][name].id }
      if contains(keys(local.existing_resource_groups[sub]), name)
    }
  ]...)
  to = module.subscription[each.value.sub].module.resourcegroup[each.value.name].azapi_resource.rg
  id = each.value.id
}

import {
  for_each = merge([
    for sub, d in data.azapi_resource_list.budgets : {
      for b in d.output.budgets : "${sub}/${b.name}" => { sub = sub, name = b.name, id = b.id }
      if contains(keys(local.config[sub].budgets), b.name)
    }
  ]...)
  to = module.subscription[each.value.sub].module.budget[each.value.name].azapi_resource.budget
  id = each.value.id
}
