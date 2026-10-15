# Management groups and Azure RBAC on them (tenant YAML `management_groups`).
# A management group's creator becomes its Owner, so the identity that applies this configuration can assign
# roles on the groups it creates without any prior Azure RBAC, as long as the tenant's hierarchy setting
# "Require write permissions for creating new management groups" is off (the default).
# Subscriptions are not moved here: that needs Owner on the subscription itself.

locals {
  tenant_root_management_group_id = "/providers/Microsoft.Management/managementGroups/${local.tenant_config.entraid_tenant_id}"

  management_groups = { for mg in try(local.tenant_config.management_groups, []) : mg.name => mg }

  # Principals named in role assignments: group or application (display names in this YAML), user (UPN),
  # or principal_id with principal_type for principals outside the YAML
  azure_rbac_principals = merge(
    { for name, g in module.entraid_group : "group/${name}" => { id = g.group_id, type = "Group" } },
    { for name, a in module.entraid_application : "application/${name}" => { id = a.service_principal_object_id, type = "ServicePrincipal" } },
    { for upn, u in module.entraid_user : "user/${upn}" => { id = u.user_id, type = "User" } },
  )

  # "<management group>|<role>|<group|application|user>/<name>" => role assignment
  management_group_role_assignments = merge([
    for mg_name, mg in local.management_groups : {
      for ra in try(mg.role_assignments, []) :
      "${mg_name}|${ra.role}|${try("group/${ra.group}", "application/${ra.application}", "user/${ra.user}", "id/${ra.principal_id}")}" => merge(ra, {
        management_group = mg_name
        principal        = try("group/${ra.group}", "application/${ra.application}", "user/${ra.user}", "id/${ra.principal_id}")
      })
    }
  ]...)
}

# Built-in role names to role definition IDs, from the module's cached data (no API calls)
module "azure_role_definitions" {
  source  = "Azure/avm-utl-roledefinitions/azure"
  version = "0.1.0"
  count   = length(local.management_groups) > 0 ? 1 : 0

  role_definition_scope = local.tenant_root_management_group_id
  use_cached_data       = true
  enable_telemetry      = false
}

resource "azapi_resource" "management_group" {
  for_each = local.management_groups

  type      = "Microsoft.Management/managementGroups@2023-04-01"
  parent_id = "/"
  name      = each.key
  body = {
    properties = {
      displayName = try(each.value.display_name, each.key)
      details = {
        parent = {
          # another management group from this YAML, or the tenant root group
          id = try(each.value.parent, null) == null ? local.tenant_root_management_group_id : "/providers/Microsoft.Management/managementGroups/${each.value.parent}"
        }
      }
    }
  }
}

resource "azapi_resource" "management_group_role_assignment" {
  for_each = local.management_group_role_assignments

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = azapi_resource.management_group[each.value.management_group].id
  name      = uuidv5("url", each.key) # stable: derived from the YAML, not from object IDs
  body = {
    properties = merge(
      {
        roleDefinitionId = try(module.azure_role_definitions[0].role_definition_rolename_to_resource_id[each.value.role], null)
        principalId      = try(local.azure_rbac_principals[each.value.principal].id, each.value.principal_id)
        principalType    = try(local.azure_rbac_principals[each.value.principal].type, each.value.principal_type)
      },
      # ABAC condition, e.g. to stop Role Based Access Control Administrator from assigning privileged roles
      try(each.value.condition, null) == null ? {} : { condition = trimspace(each.value.condition), conditionVersion = "2.0" },
    )
  }

  # The creator's Owner role on a new management group takes a moment to become effective
  retry = {
    error_message_regex = ["AuthorizationFailed"]
  }

  lifecycle {
    precondition {
      condition     = try(module.azure_role_definitions[0].role_definition_rolename_to_resource_id[each.value.role], null) != null
      error_message = "\"${each.value.role}\" is not a built-in Azure role."
    }
  }
}
