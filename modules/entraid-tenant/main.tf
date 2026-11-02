data "azuread_client_config" "current" {}

locals {
  # Users are keyed and referenced by mail_nickname, not UPN, so a domain change renames them in place
  entraid_users_by_name = {
    for user in try(var.config.users, []) : user.mail_nickname => user
  }

  entraid_groups_by_display_name = {
    for group in try(var.config.groups, []) : group.display_name => group
  }

  entraid_applications_by_display_name = {
    for app in try(var.config.applications, []) : app.display_name => app
  }

  user_ids = { for name, user in module.entraid_user : name => user.user_id }
}

# Validate that the YAML tenant ID matches the Azure tenant we're deploying to
resource "null_resource" "validate_tenant" {
  lifecycle {
    precondition {
      condition     = data.azuread_client_config.current.tenant_id == var.tenant_id
      error_message = "Tenant ID mismatch! YAML specifies '${var.tenant_id}' but you're authenticated to '${data.azuread_client_config.current.tenant_id}'. Check your YAML file or Azure credentials."
    }
  }
}

module "entraid_user" {
  source   = "../entraid-user"
  for_each = local.entraid_users_by_name

  entraid_user = each.value
}

# Managers are set here because the entraid_user module cannot reference its own instances.
locals {
  user_managers = {
    for name, user in local.entraid_users_by_name : name => user.organization.manager if try(user.organization.manager, null) != null
  }
}

resource "msgraph_resource_action" "user_manager" {
  for_each = local.user_managers

  resource_url = "users/${module.entraid_user[each.key].user_id}"
  action       = "manager/$ref"
  method       = "PUT"
  body = {
    "@odata.id" = "https://graph.microsoft.com/v1.0/users/${local.user_ids[each.value]}"
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
  source   = "../entraid-application"
  for_each = local.entraid_applications_by_display_name

  entraid_application = each.value
  user_ids            = local.user_ids
}

# Subscribed licences, for group-based licensing (read only when a group has licenses)
data "msgraph_resource" "subscribed_skus" {
  count = anytrue([for group in try(var.config.groups, []) : length(try(group.licenses, [])) > 0]) ? 1 : 0

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
  source           = "../entraid-group"
  for_each         = local.entraid_groups_by_display_name
  entraid_group    = each.value
  sku_ids          = local.sku_ids
  service_plan_ids = local.service_plan_ids
  # members can be users (by mail_nickname), applications (by display name) or guests (by email)
  member_ids = merge(
    local.user_ids,
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
    for group in try(var.config.groups, []) : [
      for role_name in try(group.entraid_role_names, []) : {
        role_name       = role_name
        assignee_name   = group.display_name
        assignment_type = "Group"
      }
    ]
  ])

  # Role assignments from users
  user_role_assignments = flatten([
    for user in try(var.config.users, []) : [
      for role_name in try(user.entraid_role_names, []) : {
        role_name       = role_name
        assignee_name   = user.mail_nickname
        assignment_type = "User"
      }
    ]
  ])

  # Role assignments from applications (assigned to the service principal)
  application_role_assignments = flatten([
    for app in try(var.config.applications, []) : [
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
    flatten([for unit in try(var.config.administrative_units, []) : [for role in try(unit.role_assignments, []) : role.role_name]]),
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
  source   = "../entraid-role-assignment"
  for_each = local.role_assignments_by_name

  role_assignment       = each.value
  role_id               = azuread_directory_role.activated[each.value.role_name].template_id
  group_ids             = { for k, v in module.entraid_group : k => v.group_id }
  user_ids              = local.user_ids
  service_principal_ids = { for k, v in module.entraid_application : k => v.service_principal_object_id }

  depends_on = [module.entraid_group, module.entraid_user, module.entraid_application]
}

# PIM eligible role assignments (require Entra ID P2)
locals {
  pim_roles_by_name = {
    for role in try(var.config.pim_roles, []) :
    "${role.role_name}-${role.assignee_name}" => role
  }

  # Maximum activation duration per role (a PIM setting of the role, not of the assignment)
  pim_role_durations = {
    for role_name, durations in {
      for role in try(var.config.pim_roles, []) : role.role_name => try(role.duration, null)...
    } : role_name => compact(durations)[0] if length(compact(durations)) > 0
  }
}

module "pim_role" {
  source   = "../entraid-pim-role"
  for_each = local.pim_roles_by_name

  pim_role              = each.value
  role_template_id      = local.role_name_to_template_id[each.value.role_name]
  group_ids             = { for k, v in module.entraid_group : k => v.group_id }
  user_ids              = local.user_ids
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
