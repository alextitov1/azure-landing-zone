# Management groups below the intermediate root, policy and Azure RBAC on them, with the Azure Verified Module for
# Azure Landing Zones. The hierarchy is an architecture definition in tenants/<tenant>/lib (management_groups.architecture).
# The intermediate root is created by tier 0 (bootstrap/Azure) and is `exists: true` there: it is not created here,
# but still gets its archetype's policy and the role assignments below. This tier's rights on it come from the
# tier-0 Contributor group.
# Subscriptions are not moved here: that needs Owner on the subscription itself.

locals {
  management_groups_config = try(local.config.management_groups, null)

  # Principals named in role assignments: group or application (display names in the tenant config), user
  # (mail_nickname, incl. existing_users), or principal_id with principal_type for principals outside the config
  azure_rbac_principals = merge(
    { for name, id in module.entraid.group_ids : "group/${name}" => { id = id, type = "Group" } },
    { for name, id in module.entraid.service_principal_ids : "application/${name}" => { id = id, type = "ServicePrincipal" } },
    { for name, id in module.entraid.user_ids : "user/${name}" => { id = id, type = "User" } },
  )

  # "<management group>|<role>|<group|application|user|id>/<name>" => module input
  management_group_role_assignments = {
    for ra in try(local.management_groups_config.role_assignments, []) :
    "${ra.management_group}|${ra.role}|${try("group/${ra.group}", "application/${ra.application}", "user/${ra.user}", "id/${ra.principal_id}")}" => {
      management_group_name      = ra.management_group
      role_definition_id_or_name = ra.role # built-in role name, looked up by the module at the group's scope
      principal_id               = try(local.azure_rbac_principals[try("group/${ra.group}", "application/${ra.application}", "user/${ra.user}")].id, ra.principal_id)
      principal_type             = try(local.azure_rbac_principals[try("group/${ra.group}", "application/${ra.application}", "user/${ra.user}")].type, ra.principal_type)
      # ABAC condition, e.g. to stop Role Based Access Control Administrator from assigning privileged roles
      condition         = try(trimspace(ra.condition), null)
      condition_version = try(ra.condition, null) == null ? null : "2.0"
    }
  }
}

module "management_groups" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.22.0"
  count   = local.management_groups_config == null ? 0 : 1

  architecture_name  = local.management_groups_config.architecture
  parent_resource_id = local.config.entraid_tenant_id # the tenant root group
  location           = try(local.management_groups_config.location, "australiaeast")
  enable_telemetry   = false

  management_group_role_assignments = local.management_group_role_assignments

  # Values for policy assignment parameters, by the default names in lib/alz_policy_default_values.json,
  # e.g. log_analytics_workspace_id. The module grants each assignment's identity the roles its definition
  # needs, on the management group and on resources passed in parameters marked assignPermissions.
  policy_default_values = {
    for name, value in try(local.management_groups_config.policy_default_values, {}) : name => jsonencode({ value = value })
  }
}
