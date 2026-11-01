# Tier 0 of the 4esnok_vs tenant: admin and break-glass users, tier-0 groups, and the intermediate root management
# group with its RBAC and hierarchy settings. See ../README.md.
terraform {
  cloud {
    organization = "4esnok"
    workspaces { name = "4esnok_vs_azure_bootstrap_r0" }
  }

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
  }
}

locals {
  config               = yamldecode(file("${path.module}/config.yaml"))
  intermediate_root    = local.config.management_groups
  tenant_root_group_id = "/providers/Microsoft.Management/managementGroups/${local.config.entraid_tenant_id}"
}

module "entraid" {
  source = "../../../modules/entraid-tenant"

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.entra_id
}

# azapi rather than azurerm: azurerm needs a subscription, and the Global Administrator may have none yet
resource "azapi_resource" "intermediate_root" {
  type      = "Microsoft.Management/managementGroups@2023-04-01"
  parent_id = "/"
  name      = local.intermediate_root.name
  body = {
    properties = {
      displayName = local.intermediate_root.display_name
      details     = { parent = { id = local.tenant_root_group_id } }
    }
  }
}

# Built-in role IDs by name, so the config can name roles
data "azapi_resource_list" "role_definition" {
  for_each = toset([for ra in local.intermediate_root.role_assignments : ra.role])

  type                   = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  parent_id              = local.tenant_root_group_id
  query_parameters       = { "$filter" = ["roleName eq '${each.key}'"] }
  response_export_values = { id = "value[0].id" }
}

resource "azapi_resource" "intermediate_root_role_assignment" {
  for_each = { for ra in local.intermediate_root.role_assignments : "${ra.role}|${ra.group}" => ra }

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = azapi_resource.intermediate_root.id
  # Role assignment names are GUIDs; derived from the assignment so a new plan doesn't replace it
  name = uuidv5("url", "${local.intermediate_root.name}|${each.key}")
  body = {
    properties = {
      roleDefinitionId = data.azapi_resource_list.role_definition[each.value.role].output.id
      principalId      = module.entraid.group_ids[each.value.group]
      principalType    = "Group" # skips the principal lookup, which fails while a new group is still replicating
    }
  }
}

# Set on the tenant root group: the applying identity needs Hierarchy Settings Administrator there (../README.md)
resource "azapi_resource" "hierarchy_settings" {
  type      = "Microsoft.Management/managementGroups/settings@2023-04-01"
  parent_id = local.tenant_root_group_id
  name      = "default"
  body = {
    properties = {
      defaultManagementGroup               = azapi_resource.intermediate_root.id
      requireAuthorizationForGroupCreation = try(local.intermediate_root.require_authorization_for_group_creation, false)
    }
  }
}
