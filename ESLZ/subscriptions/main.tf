# Subscriptions of the 4esnok.su tenant: one YAML file per subscription in ./config (see README.md), each
# managed by the Azure Verified Module for subscription vending, used here for existing subscriptions only.

locals {
  # YAML files with their optional sections as empty collections (`try` also covers a key left without a value)
  subscriptions = {
    for f in fileset("${path.module}/config", "*.yaml") : trimsuffix(f, ".yaml") => {
      for k, v in yamldecode(file("${path.module}/config/${f}")) : k => v
    }
  }
  config = {
    for sub, s in local.subscriptions : sub => {
      subscription_id     = s.subscription_id
      location            = try(s.location, "australiaeast")
      display_name        = try(s.display_name, null)
      tags                = try({ for k, v in s.tags : k => v }, {})
      management_group_id = try(s.management_group_id, null)
      resource_providers  = try({ for ns, features in s.resource_providers : ns => toset(try([for f in features : f], [])) }, {})
      budgets             = try({ for name, b in s.budgets : name => b }, {})
      role_assignments    = try([for a in s.role_assignments : a], [])
      resource_groups = try({
        for name, rg in s.resource_groups : name => {
          location         = try(rg.location, null)
          tags             = try({ for k, v in rg.tags : k => v }, {})
          lock             = try(rg.lock, false)
          role_assignments = try([for a in rg.role_assignments : a], [])
        }
      }, {})
    }
  }

  # Every role assignment in the YAML files, at subscription scope (resource_group = null) and per resource group
  role_assignments = {
    for sub, c in local.config : sub => concat(
      [for a in c.role_assignments : merge(a, { resource_group = null })],
      flatten([for rg_name, rg in c.resource_groups : [for a in rg.role_assignments : merge(a, { resource_group = rg_name })]]),
    )
  }
  all_role_assignments = flatten(values(local.role_assignments))
}

# Principals named in role assignments: group (display name), user (user principal name) or
# service_principal (display name). principal_id with principal_type skips the lookup.
data "azuread_group" "this" {
  for_each = toset([for a in local.all_role_assignments : a.group if try(a.group, null) != null])

  display_name     = each.key
  security_enabled = true
}

data "azuread_user" "this" {
  for_each = toset([for a in local.all_role_assignments : a.user if try(a.user, null) != null])

  user_principal_name = each.key
}

data "azuread_service_principal" "this" {
  for_each = toset([for a in local.all_role_assignments : a.service_principal if try(a.service_principal, null) != null])

  display_name = each.key
}

locals {
  principals = merge(
    { for name, g in data.azuread_group.this : "group/${name}" => { id = g.object_id, type = "Group" } },
    { for upn, u in data.azuread_user.this : "user/${upn}" => { id = u.object_id, type = "User" } },
    { for name, sp in data.azuread_service_principal.this : "service_principal/${name}" => { id = sp.object_id, type = "ServicePrincipal" } },
  )

  # <subscription> => { "<resource group or subscription>|<role>|<principal>" => sub-vending role assignment }
  vending_role_assignments = {
    for sub, assignments in local.role_assignments : sub => {
      for a in assignments : join("|", [
        coalesce(a.resource_group, "subscription"),
        a.role,
        try("group/${a.group}", "user/${a.user}", "service_principal/${a.service_principal}", a.principal_id),
        ]) => {
        definition               = a.role
        resource_group_scope_key = a.resource_group
        principal_id = try(
          local.principals["group/${a.group}"].id, local.principals["user/${a.user}"].id,
          local.principals["service_principal/${a.service_principal}"].id, a.principal_id,
        )
        principal_type = try(
          local.principals["group/${a.group}"].type, local.principals["user/${a.user}"].type,
          local.principals["service_principal/${a.service_principal}"].type, a.principal_type,
        )
      }
    }
  }
}

module "subscription" {
  source   = "Azure/avm-ptn-alz-sub-vending/azure"
  version  = "0.3.4"
  for_each = local.config

  location         = each.value.location
  enable_telemetry = false

  # Existing subscription: never created or cancelled. Renaming and tagging need display_name.
  subscription_alias_enabled   = false
  subscription_id              = each.value.subscription_id
  subscription_update_existing = each.value.display_name != null
  subscription_display_name    = each.value.display_name
  subscription_tags            = each.value.tags

  subscription_management_group_association_enabled = each.value.management_group_id != null
  subscription_management_group_id                  = each.value.management_group_id

  # Only the namespaces in the YAML, not the module's default list
  subscription_register_resource_providers_enabled      = length(each.value.resource_providers) > 0
  subscription_register_resource_providers_and_features = each.value.resource_providers

  resource_group_creation_enabled = length(each.value.resource_groups) > 0
  resource_groups = {
    for name, rg in each.value.resource_groups : name => {
      name         = name
      location     = rg.location
      tags         = rg.tags
      lock_enabled = rg.lock
    }
  }

  role_assignment_enabled = length(local.vending_role_assignments[each.key]) > 0
  role_assignments        = local.vending_role_assignments[each.key]

  budget_enabled = length(each.value.budgets) > 0
  budgets = {
    for name, b in each.value.budgets : name => {
      name              = name
      amount            = b.amount
      time_grain        = try(b.time_grain, "Monthly")
      time_period_start = "${b.start_date}T00:00:00Z"
      time_period_end   = try("${b.end_date}T00:00:00Z", timeadd("${b.start_date}T00:00:00Z", "87600h")) # default: 10 years
      notifications = {
        for n in try([for n in b.notifications : n], []) :
        "${try(n.threshold_type, "Actual")}_${try(n.operator, "GreaterThan")}_${n.threshold}" => {
          enabled        = true
          operator       = try(n.operator, "GreaterThan")
          threshold      = n.threshold
          threshold_type = try(n.threshold_type, "Actual")
          contact_emails = try(n.contact_emails, [])
          contact_roles  = try(n.contact_roles, ["Owner"])
        }
      }
    }
  }
}
