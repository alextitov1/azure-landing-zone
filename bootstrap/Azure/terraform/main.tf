data "azuread_client_config" "current" {}

locals {
  tenant_config = yamldecode(file(var.tenant_yaml_path))

  entraid_users_by_upn = {
    for user in local.tenant_config.users : user.user_principal_name => user
  }

  entraid_groups_by_display_name = {
    for group in local.tenant_config.groups : group.display_name => group
  }

  entraid_applications_by_display_name = {
    for app in try(local.tenant_config.applications, []) : app.display_name => app
  }

  # Emergency access (break-glass) accounts: excluded from every Conditional Access policy
  break_glass_upns = [
    for user in local.tenant_config.users : user.user_principal_name if try(user.break_glass, false)
  ]
}

# Validate that the YAML tenant ID matches the Azure tenant we're deploying to
resource "null_resource" "validate_tenant" {
  lifecycle {
    precondition {
      condition     = data.azuread_client_config.current.tenant_id == local.tenant_config.entraid_tenant_id
      error_message = "Tenant ID mismatch! YAML specifies '${local.tenant_config.entraid_tenant_id}' but you're authenticated to '${data.azuread_client_config.current.tenant_id}'. Check your YAML file or Azure credentials."
    }
    precondition {
      condition = alltrue([
        for name in keys(local.entraid_groups_by_display_name) : can(regex("^(sg|m365)-t[0-2]-(entra|az|app|org)(-[a-z0-9]+)+$", name))
      ])
      error_message = "Group names must follow sg-<tier>-<target>-<scope>-<role>, e.g. sg-t0-entra-tenant-globaladmin (see README, Naming)."
    }
    precondition {
      condition = alltrue([
        for name in keys(local.entraid_applications_by_display_name) : can(regex("^(sp|app|mi)-t[0-2](-[a-z0-9]+){2,}$", name))
      ])
      error_message = "Application names must follow <sp|app|mi>-<tier>-<consumer>-<target>-<access>, e.g. sp-t0-hcp-entraid-bootstrap-apply (see README, Naming)."
    }
    precondition {
      condition = alltrue([
        for user in local.tenant_config.users : try(user.store_password_in_key_vault, false) if try(user.break_glass, false)
      ])
      error_message = "Break-glass users must set store_password_in_key_vault: true, so their password is kept in 1Password."
    }
    precondition {
      condition = contains(
        [for domain in data.azuread_domains.all.domains : domain.domain_name if domain.verified],
        local.tenant_config.default_custom_domain
      )
      error_message = "Domain '${local.tenant_config.default_custom_domain}' (default_custom_domain) is not a verified domain in this tenant."
    }
  }
}

module "entraid_user" {
  source   = "./modules/entraid_user"
  for_each = local.entraid_users_by_upn

  entraid_user = each.value
}

# Managers are set here because the entraid_user module cannot reference its own instances.
locals {
  user_managers = {
    for upn, user in local.entraid_users_by_upn : upn => user.manager if try(user.manager, null) != null
  }
}

resource "msgraph_resource_action" "user_manager" {
  for_each = local.user_managers

  resource_url = "users/${module.entraid_user[each.key].user_id}"
  action       = "manager/$ref"
  method       = "PUT"
  body = {
    "@odata.id" = "https://graph.microsoft.com/v1.0/users/${module.entraid_user[each.value].user_id}"
  }
}

# Clears the manager when it is taken out of the YAML
resource "msgraph_resource_action" "user_manager_removal" {
  for_each = local.user_managers

  resource_url = "users/${module.entraid_user[each.key].user_id}"
  action       = "manager/$ref"
  method       = "DELETE"
  when         = "destroy"
}

module "entraid_application" {
  source   = "./modules/entraid_application"
  for_each = local.entraid_applications_by_display_name

  entraid_application = each.value
  user_ids            = { for k, v in module.entraid_user : k => v.user_id }
}

# Subscribed licences, for group-based licensing (read only when a group has licenses)
data "msgraph_resource" "subscribed_skus" {
  count = anytrue([for group in local.tenant_config.groups : length(try(group.licenses, [])) > 0]) ? 1 : 0

  url = "subscribedSkus"
  response_export_values = {
    skus = "value[].{sku: skuPartNumber, id: skuId, plans: servicePlans[].{name: servicePlanName, id: servicePlanId}}"
  }
}

locals {
  subscribed_skus  = try(data.msgraph_resource.subscribed_skus[0].output.skus, [])
  sku_ids          = { for sku in local.subscribed_skus : sku.sku => sku.id }
  service_plan_ids = { for sku in local.subscribed_skus : sku.sku => { for plan in sku.plans : plan.name => plan.id } }
}

module "entraid_group" {
  source           = "./modules/entraid_group"
  for_each         = local.entraid_groups_by_display_name
  entraid_group    = each.value
  sku_ids          = local.sku_ids
  service_plan_ids = local.service_plan_ids
  # members can be users (by user principal name), applications (by display name) or guests (by email)
  member_ids = merge(
    { for k, v in module.entraid_user : k => v.user_id },
    { for k, v in module.entraid_application : k => v.service_principal_object_id },
    { for k, v in azuread_invitation.this : k => v.user_id },
  )

  depends_on = [module.entraid_user, module.entraid_application]
}

# Permanent (active) Entra ID role assignments (defined at group and user level)
data "azuread_directory_role_templates" "all" {}

locals {
  # Role assignments from groups
  group_role_assignments = flatten([
    for group in try(local.tenant_config.groups, []) : [
      for role_name in try(group.entraid_role_names, []) : {
        role_name       = role_name
        assignee_name   = group.display_name
        assignment_type = "Group"
      }
    ]
  ])

  # Role assignments from users
  user_role_assignments = flatten([
    for user in try(local.tenant_config.users, []) : [
      for role_name in try(user.entraid_role_names, []) : {
        role_name       = role_name
        assignee_name   = user.user_principal_name
        assignment_type = "User"
      }
    ]
  ])

  # Role assignments from applications (assigned to the service principal)
  application_role_assignments = flatten([
    for app in try(local.tenant_config.applications, []) : [
      for role_name in try(app.entraid_role_names, []) : {
        role_name       = role_name
        assignee_name   = app.display_name
        assignment_type = "ServicePrincipal"
      }
    ]
  ])

  # Combined role assignments
  role_assignments_by_name = {
    for role in concat(local.group_role_assignments, local.user_role_assignments, local.application_role_assignments) :
    "${role.role_name}-${role.assignee_name}" => role
  }

  # Get unique role names that need to be activated (directory and administrative unit role assignments)
  unique_role_names = distinct(concat(
    [for k, v in local.role_assignments_by_name : v.role_name],
    flatten([for unit in try(local.tenant_config.administrative_units, []) : [for role in try(unit.role_assignments, []) : role.role_name]]),
  ))

  # Map role names to template IDs
  role_name_to_template_id = {
    for role in data.azuread_directory_role_templates.all.role_templates :
    role.display_name => role.object_id
  }
}

# Activate directory roles once (shared across all assignments)
resource "azuread_directory_role" "activated" {
  for_each    = toset(local.unique_role_names)
  template_id = local.role_name_to_template_id[each.key]
}

module "entraid_role_assignment" {
  source   = "./modules/entraid_role_assignment"
  for_each = local.role_assignments_by_name

  role_assignment       = each.value
  role_id               = azuread_directory_role.activated[each.value.role_name].template_id
  group_ids             = { for k, v in module.entraid_group : k => v.group_id }
  user_ids              = { for k, v in module.entraid_user : k => v.user_id }
  service_principal_ids = { for k, v in module.entraid_application : k => v.service_principal_object_id }

  depends_on = [module.entraid_group, module.entraid_user, module.entraid_application]
}

# PIM eligible role assignments (require Entra ID P2)
locals {
  pim_roles_by_name = {
    for role in try(local.tenant_config.pim_roles, []) :
    "${role.role_name}-${role.assignee_name}" => role
  }

  # Maximum activation duration per role (a PIM setting of the role, not of the assignment)
  pim_role_durations = {
    for role_name, durations in {
      for role in try(local.tenant_config.pim_roles, []) : role.role_name => try(role.duration, null)...
    } : role_name => compact(durations)[0] if length(compact(durations)) > 0
  }
}

module "pim_role" {
  source   = "./modules/pim_role"
  for_each = local.pim_roles_by_name

  pim_role              = each.value
  role_template_id      = local.role_name_to_template_id[each.value.role_name]
  group_ids             = { for k, v in module.entraid_group : k => v.group_id }
  user_ids              = { for k, v in module.entraid_user : k => v.user_id }
  service_principal_ids = { for k, v in module.entraid_application : k => v.service_principal_object_id }

  depends_on = [module.entraid_group, module.entraid_user, module.entraid_application]
}

data "msgraph_resource" "pim_role_policy" {
  for_each = local.pim_role_durations

  url = "policies/roleManagementPolicyAssignments"
  query_parameters = {
    "$filter" = ["scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '${local.role_name_to_template_id[each.key]}'"]
  }
  response_export_values = {
    policy_id = "value[0].policyId"
  }
}

resource "msgraph_update_resource" "pim_activation_duration" {
  for_each = local.pim_role_durations

  url = "policies/roleManagementPolicies/${data.msgraph_resource.pim_role_policy[each.key].output.policy_id}/rules/Expiration_EndUser_Assignment"
  body = {
    "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
    id                   = "Expiration_EndUser_Assignment"
    isExpirationRequired = true
    maximumDuration      = each.value
    target = {
      caller     = "EndUser"
      operations = ["All"]
      level      = "Assignment"
    }
  }
}
