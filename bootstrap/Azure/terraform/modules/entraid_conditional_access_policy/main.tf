# Conditional Access policy (requires Entra ID P1)

locals {
  special_users     = ["All", "None", "GuestsOrExternalUsers"]
  special_locations = ["All", "AllTrusted"]

  users = var.policy.users

  included_users = [for u in local.users.include : contains(local.special_users, u) ? u : var.user_ids[u]]
  excluded_users = distinct(concat(
    [for u in local.users.exclude : contains(local.special_users, u) ? u : var.user_ids[u]],
    var.always_excluded_user_ids,
  ))
}

resource "azuread_conditional_access_policy" "this" {
  display_name = var.policy.display_name
  state        = var.policy.state

  conditions {
    client_app_types = var.policy.client_app_types

    applications {
      included_applications = var.policy.applications.include
      excluded_applications = var.policy.applications.exclude
    }

    users {
      included_users  = local.included_users
      excluded_users  = local.excluded_users
      included_groups = [for g in local.users.include_groups : var.group_ids[g]]
      excluded_groups = [for g in local.users.exclude_groups : var.group_ids[g]]
      included_roles  = [for r in local.users.include_roles : var.role_template_ids[r]]
      excluded_roles  = [for r in local.users.exclude_roles : var.role_template_ids[r]]
    }

    dynamic "locations" {
      for_each = var.policy.locations != null ? [var.policy.locations] : []
      content {
        included_locations = [for l in locations.value.include : contains(local.special_locations, l) ? l : var.named_location_ids[l]]
        excluded_locations = [for l in locations.value.exclude : contains(local.special_locations, l) ? l : var.named_location_ids[l]]
      }
    }
  }

  grant_controls {
    operator                          = var.policy.grant.operator
    built_in_controls                 = length(var.policy.grant.controls) > 0 ? var.policy.grant.controls : null
    authentication_strength_policy_id = var.policy.grant.authentication_strength != null ? var.authentication_strength_ids[var.policy.grant.authentication_strength] : null
  }
}
