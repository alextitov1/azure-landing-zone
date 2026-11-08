# Subscription vending with the Azure Verified Module (Azure/avm-ptn-alz-sub-vending), for existing subscriptions
# only: one module call per landing zone. Landing zones that share a subscription stand in for subscriptions of
# their own with their resource groups, so giving one its own subscription is a change of subscription_id.

locals {
  # Optional sections as empty collections (`try` also covers a key left without a value)
  config = {
    for lz, s in var.landing_zones : lz => {
      subscription_id     = s.subscription_id
      location            = s.location
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
      managed_identities = try({
        for name, mi in s.managed_identities : name => {
          resource_group   = mi.resource_group
          role_assignments = try([for a in mi.role_assignments : a], [])
        }
      }, {})
    }
  }

  # Every role assignment of a landing zone, at subscription scope (resource_group = null) and per resource group
  role_assignments = {
    for lz, c in local.config : lz => concat(
      [for a in c.role_assignments : merge(a, { resource_group = null })],
      flatten([for rg_name, rg in c.resource_groups : [for a in rg.role_assignments : merge(a, { resource_group = rg_name })]]),
    )
  }
  all_role_assignments = flatten(values(local.role_assignments))
}

# Principals named in role assignments: group or service_principal (display name). principal_id with
# principal_type skips the lookup. Users get access through groups, so they can't be named.
data "azuread_group" "this" {
  for_each = toset([for a in local.all_role_assignments : a.group if try(a.group, null) != null])

  display_name     = each.key
  security_enabled = true
}

data "azuread_service_principal" "this" {
  for_each = toset([for a in local.all_role_assignments : a.service_principal if try(a.service_principal, null) != null])

  display_name = each.key
}

locals {
  principals = merge(
    { for name, g in data.azuread_group.this : "group/${name}" => { id = g.object_id, type = "Group" } },
    { for name, sp in data.azuread_service_principal.this : "service_principal/${name}" => { id = sp.object_id, type = "ServicePrincipal" } },
  )

  # <landing zone> => { "<resource group or subscription>|<role>|<principal>" => sub-vending role assignment }
  vending_role_assignments = {
    for lz, assignments in local.role_assignments : lz => {
      for a in assignments : join("|", [
        coalesce(a.resource_group, "subscription"),
        a.role,
        try("group/${a.group}", "service_principal/${a.service_principal}", a.principal_id),
        ]) => {
        definition               = a.role
        resource_group_scope_key = a.resource_group
        principal_id = try(
          local.principals["group/${a.group}"].id, local.principals["service_principal/${a.service_principal}"].id,
          a.principal_id,
        )
        principal_type = try(
          local.principals["group/${a.group}"].type, local.principals["service_principal/${a.service_principal}"].type,
          a.principal_type,
        )
        # ABAC condition, e.g. to limit Role Based Access Control Administrator to the roles a pipeline hands out
        condition         = try(trimspace(a.condition), null)
        condition_version = try(a.condition, null) == null ? null : "2.0"
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

  # The name is read from the hierarchy's IDs, so the placement waits for the management group to exist
  subscription_management_group_association_enabled = each.value.management_group_id != null
  subscription_management_group_id                  = each.value.management_group_id == null ? null : basename(var.management_group_ids[each.value.management_group_id])

  # Only the namespaces in the YAML, not the module's default list. Each landing zone lists what its own stack
  # deploys, because its pipeline has no rights to register them; registering a namespace twice is harmless.
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

  # User-assigned managed identities with their role assignments, for workloads whose pipelines cannot assign
  # roles. Each assignment is scoped to a resource group of the same landing zone, a resource (scope) or the
  # subscription.
  umi_enabled = length(each.value.managed_identities) > 0
  user_managed_identities = {
    for name, mi in each.value.managed_identities : name => {
      name               = name
      resource_group_key = mi.resource_group
      role_assignments = {
        for a in mi.role_assignments : "${coalesce(try(a.resource_group, null), try(a.scope, null), "subscription")}|${a.role}" => {
          definition               = a.role
          resource_group_scope_key = try(a.resource_group, null)
          relative_scope           = try(a.scope, "")
          principal_type           = "ServicePrincipal" # the new identity may not have replicated to Entra ID yet
        }
      }
    }
  }

  budget_enabled = length(each.value.budgets) > 0
  budgets = {
    for name, b in each.value.budgets : name => {
      name               = name
      amount             = b.amount
      time_grain         = try(b.time_grain, "Monthly")
      time_period_start  = "${b.start_date}T00:00:00Z"
      time_period_end    = try("${b.end_date}T00:00:00Z", timeadd("${b.start_date}T00:00:00Z", "87600h")) # default: 10 years
      resource_group_key = try(b.resource_group, null)                                                    # null: the subscription
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
