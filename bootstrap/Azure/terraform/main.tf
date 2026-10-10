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
}

# Validate that the YAML tenant ID matches the Azure tenant we're deploying to
resource "null_resource" "validate_tenant" {
  lifecycle {
    precondition {
      condition     = data.azuread_client_config.current.tenant_id == local.tenant_config.entraid_tenant_id
      error_message = "Tenant ID mismatch! YAML specifies '${local.tenant_config.entraid_tenant_id}' but you're authenticated to '${data.azuread_client_config.current.tenant_id}'. Check your YAML file or Azure credentials."
    }
  }
}

module "entraid_user" {
  source   = "./modules/entraid_user"
  for_each = local.entraid_users_by_upn

  entraid_user = each.value
}

module "entraid_application" {
  source   = "./modules/entraid_application"
  for_each = local.entraid_applications_by_display_name

  entraid_application = each.value
  user_ids            = { for k, v in module.entraid_user : k => v.user_id }
}

module "entraid_group" {
  source        = "./modules/entraid_group"
  for_each      = local.entraid_groups_by_display_name
  entraid_group = each.value
  # members can be users (by user principal name) or applications (by display name)
  member_ids = merge(
    { for k, v in module.entraid_user : k => v.user_id },
    { for k, v in module.entraid_application : k => v.service_principal_object_id },
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

  # Get unique role names that need to be activated
  unique_role_names = distinct([for k, v in local.role_assignments_by_name : v.role_name])

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

# PIM role eligibility assignments
## There is bug in the az cli https://github.com/hashicorp/terraform-provider-azuread/issues/1234
## if authenticated as a user, so we comment this out for now.
# locals {
#   pim_roles_by_name = {
#     for role in try(local.tenant_config.pim_roles, []) :
#     "${role.role_name}-${role.assignee_name}" => role
#   }
# }

# module "pim_role" {
#   source   = "./modules/pim_role"
#   for_each = local.pim_roles_by_name

#   pim_role  = each.value
#   group_ids = { for k, v in module.entraid_group : k => v.group_id }
#   user_ids  = { for k, v in module.entraid_user : k => v.user_id }

#   depends_on = [module.entraid_group, module.entraid_user]
# }
