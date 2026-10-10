# Entra ID identities for an HCP Terraform workspace, using workload identity federation (OIDC).
# The plan phase and the apply phase each get their own app registration, so plans run with read-only access.

locals {
  run_phases = toset(["plan", "apply"])

  graph_app_roles = {
    plan  = var.plan_graph_app_roles
    apply = var.apply_graph_app_roles
  }

  graph_app_role_assignments = {
    for pair in flatten([
      for phase, roles in local.graph_app_roles : [
        for role in roles : { phase = phase, role = role }
      ]
    ]) : "${pair.phase}-${pair.role}" => pair
  }
}

resource "azuread_application" "this" {
  for_each     = local.run_phases
  display_name = "hcp-${var.workspace}-${each.key}"
  notes        = "HCP Terraform ${each.key} identity for ${var.organization}/${var.project}/${var.workspace}. Managed by terraform."
}

resource "azuread_service_principal" "this" {
  for_each  = local.run_phases
  client_id = azuread_application.this[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "this" {
  for_each       = local.run_phases
  application_id = azuread_application.this[each.key].id
  display_name   = "hcp-${var.workspace}-${each.key}"
  description    = "HCP Terraform ${each.key} runs of ${var.organization}/${var.project}/${var.workspace}"
  issuer         = "https://${var.hostname}"
  audiences      = ["api://AzureADTokenExchange"]
  subject        = "organization:${var.organization}:project:${var.project}:workspace:${var.workspace}:run_phase:${each.key}"
}

# Microsoft Graph application permissions (admin consent is implied by the assignment)
data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

resource "azuread_app_role_assignment" "graph" {
  for_each            = local.graph_app_role_assignments
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.value.role]
  principal_object_id = azuread_service_principal.this[each.value.phase].object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# HCP Terraform workspace variables that switch the workspace to dynamic Azure credentials
data "tfe_workspace" "this" {
  count        = var.set_workspace_variables ? 1 : 0
  organization = var.organization
  name         = var.workspace
}

resource "tfe_variable" "this" {
  for_each = var.set_workspace_variables ? merge(
    {
      TFC_AZURE_PROVIDER_AUTH   = "true"
      TFC_AZURE_PLAN_CLIENT_ID  = azuread_application.this["plan"].client_id
      TFC_AZURE_APPLY_CLIENT_ID = azuread_application.this["apply"].client_id
      ARM_TENANT_ID             = var.tenant_id
    },
    var.subscription_id == null ? {} : { ARM_SUBSCRIPTION_ID = var.subscription_id }
  ) : {}

  workspace_id = data.tfe_workspace.this[0].id
  key          = each.key
  value        = each.value
  category     = "env"
  description  = "Managed by terraform (bootstrap/Azure hcp_workload_identity)"
}
