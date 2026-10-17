# Management groups and Azure RBAC on them, with the Azure Verified Module for Azure Landing Zones.
# The hierarchy is an architecture definition in ./lib, chosen by the tenant YAML (management_groups.architecture);
# the role assignments are in the tenant YAML. A management group's creator becomes its Owner, so the identity that
# applies this configuration can assign roles on the groups it creates without any prior Azure RBAC, as long as the
# tenant's hierarchy setting "Require write permissions for creating new management groups" is off (the default).
# Subscriptions are not moved here: that needs Owner on the subscription itself.

locals {
  management_groups_config = try(local.tenant_config.management_groups, null)

  # Principals named in role assignments: group or application (display names in this YAML), user (UPN),
  # or principal_id with principal_type for principals outside the YAML
  azure_rbac_principals = merge(
    { for name, g in module.entraid_group : "group/${name}" => { id = g.group_id, type = "Group" } },
    { for name, a in module.entraid_application : "application/${name}" => { id = a.service_principal_object_id, type = "ServicePrincipal" } },
    { for upn, u in module.entraid_user : "user/${upn}" => { id = u.user_id, type = "User" } },
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
  parent_resource_id = local.tenant_config.entraid_tenant_id # the tenant root group
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
