# The CAF intermediate root: one management group below the tenant root group, Azure RBAC on it for Entra ID groups,
# and the tenant's hierarchy settings. The groups below it are built by tier 1 (entraid).
# azapi rather than azurerm: azurerm needs a subscription, and the Global Administrator may have none yet

locals {
  tenant_root_group_id = "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"
}

resource "azapi_resource" "intermediate_root" {
  type      = "Microsoft.Management/managementGroups@2023-04-01"
  parent_id = "/"
  name      = var.config.name
  body = {
    properties = {
      displayName = var.config.display_name
      details     = { parent = { id = local.tenant_root_group_id } }
    }
  }
}

# Built-in role IDs by name, so the config can name roles
data "azapi_resource_list" "role_definition" {
  for_each = toset([for ra in var.config.role_assignments : ra.role])

  type                   = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  parent_id              = local.tenant_root_group_id
  query_parameters       = { "$filter" = ["roleName eq '${each.key}'"] }
  response_export_values = { id = "value[0].id" }
}

resource "azapi_resource" "intermediate_root_role_assignment" {
  for_each = { for ra in var.config.role_assignments : "${ra.role}|${ra.group}" => ra }

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = azapi_resource.intermediate_root.id
  # Role assignment names are GUIDs; derived from the assignment so a new plan doesn't replace it
  name = uuidv5("url", "${var.config.name}|${each.key}")
  body = {
    properties = {
      roleDefinitionId = data.azapi_resource_list.role_definition[each.value.role].output.id
      principalId      = var.group_ids[each.value.group]
      principalType    = "Group" # skips the principal lookup, which fails while a new group is still replicating
    }
  }
}

# Set on the tenant root group: the applying identity needs Hierarchy Settings Administrator there (bootstrap/Azure/README.md)
resource "azapi_resource" "hierarchy_settings" {
  type      = "Microsoft.Management/managementGroups/settings@2023-04-01"
  parent_id = local.tenant_root_group_id
  name      = "default"
  body = {
    properties = {
      defaultManagementGroup               = azapi_resource.intermediate_root.id
      requireAuthorizationForGroupCreation = try(var.config.require_authorization_for_group_creation, false)
    }
  }
}
