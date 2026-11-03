# Management groups below the intermediate root, Azure Policy and Azure RBAC on them, from
# ../config/governance.yaml with the Azure Verified Module for Azure Landing Zones. The hierarchy is an architecture
# definition in ../lib (management_groups.architecture). The intermediate root is created by tier 0 (bootstrap/Azure)
# and is `exists: true` there: it is not created here, but still gets its archetype's policy and the role assignments
# below. This workspace's rights on it come from tier 0 (sg-prd-az-root-mgmt-t0 for apply runs,
# sg-prd-az-root-reader-t0 for plans). Subscriptions are not moved here: that needs Owner on the subscription itself.

locals {
  config           = yamldecode(file("${path.module}/../config/governance.yaml"))
  role_assignments = try(local.config.management_groups.role_assignments, [])
}

# Groups named in role assignments, created by Entra ID tier 1 (entraid). Looked up rather than read from its
# state, so this workspace doesn't depend on that one; a missing group fails the plan.
data "azuread_group" "role_assignment" {
  for_each = toset([for ra in local.role_assignments : ra.group if try(ra.group, null) != null])

  display_name     = each.key
  security_enabled = true
}

module "management_groups" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.22.0"

  architecture_name  = local.config.management_groups.architecture
  parent_resource_id = local.config.tenant_id # the tenant root group
  location           = local.config.management_groups.location
  enable_telemetry   = false

  # "<management group>|<role>|group/<name> or id/<principal ID>" => module input
  management_group_role_assignments = {
    for ra in local.role_assignments :
    "${ra.management_group}|${ra.role}|${try("group/${ra.group}", "id/${ra.principal_id}")}" => {
      management_group_name      = ra.management_group
      role_definition_id_or_name = ra.role # built-in role name, looked up by the module at the group's scope
      principal_id               = try(data.azuread_group.role_assignment[ra.group].object_id, ra.principal_id)
      principal_type             = try(ra.group, null) != null ? "Group" : ra.principal_type
      # ABAC condition, e.g. to stop Role Based Access Control Administrator from assigning privileged roles
      condition         = try(trimspace(ra.condition), null)
      condition_version = try(ra.condition, null) == null ? null : "2.0"
    }
  }

  # Values for policy assignment parameters, by the default names in ../lib/alz_policy_default_values.json,
  # e.g. log_analytics_workspace_id. The module grants each assignment's identity the roles its definition
  # needs, on the management group and on resources passed in parameters marked assignPermissions.
  policy_default_values = {
    for name, value in try(local.config.management_groups.policy_default_values, {}) : name => jsonencode({ value = value })
  }
}
