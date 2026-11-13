# The management groups below the CAF intermediate root, with Azure Policy and Azure RBAC on them, built by the Azure
# Verified Module for Azure Landing Zones. The hierarchy and policy come from the ALZ library that the caller's alz
# provider loads; the intermediate root itself is tier 0's (../azure-intermediate-root-management-group).

# Without it, a run signed in to another tenant fails later, on the first management group, with an unclear error
data "azapi_client_config" "current" {
  lifecycle {
    postcondition {
      condition     = self.tenant_id == var.tenant_id
      error_message = "Signed in to tenant ${self.tenant_id}, but the config is for tenant ${var.tenant_id}."
    }
  }
}

locals {
  role_assignments = flatten([
    for management_group, assignments in try(var.config.role_assignments, {}) : [
      for ra in assignments : merge(ra, { management_group = management_group })
    ]
  ])
}

# Groups named in role assignments, created by Entra ID tier 1 (entraid). Looked up rather than read from its state,
# so this workspace doesn't depend on that one; a missing group fails the plan.
data "azuread_group" "role_assignment" {
  for_each = toset([for ra in local.role_assignments : ra.group if try(ra.group, null) != null])

  display_name     = each.key
  security_enabled = true
}

module "alz" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.22.0"

  architecture_name  = var.config.architecture
  parent_resource_id = var.tenant_id # the tenant root group
  location           = var.config.location
  enable_telemetry   = false

  # JSON-encoded, as the module's input is map(string) to take values of any type
  policy_default_values = {
    for name, value in try(var.config.policy_default_values, {}) : name => jsonencode({ value = value })
  }

  # Parameters that name a resource of another workspace: the module would assign the policy's identity a role on
  # that resource, and waits an hour for one that doesn't exist. The role is assigned where the resource is vended.
  override_policy_definition_parameter_assign_permissions_unset = try(toset([
    for p in var.config.policy_assign_permissions_unset : {
      definition_name = p.definition_name
      parameter_name  = p.parameter_name
    }
  ]), null)

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
}
