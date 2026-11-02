# Points HCP Terraform workspaces at Entra ID applications for dynamic credentials, by writing each application's
# client ID to the workspace, so a rebuild needs no copying. The application's federated credential for the workspace
# is configured on the application (federated_credentials); the tenant comes from the project's variable set.

locals {
  # "<workspace>/<variable>" => client ID; two applications setting the same variable on a workspace fail here
  client_id_variables = {
    for v in flatten([
      for app in var.config : [
        for ws in app.hcp_workspaces : {
          workspace = ws.name
          key       = ws.run_phase == null ? "TFC_AZURE_RUN_CLIENT_ID" : "TFC_AZURE_${upper(ws.run_phase)}_CLIENT_ID"
          app       = app.display_name
        }
      ]
    ]) : "${v.workspace}/${v.key}" => v
  }
}

# Created by the HCP tiers before this one runs
data "tfe_workspace" "this" {
  for_each = toset([for v in values(local.client_id_variables) : v.workspace])

  name         = each.key
  organization = var.organization
}

resource "tfe_variable" "client_id" {
  for_each = local.client_id_variables

  workspace_id = data.tfe_workspace.this[each.value.workspace].id
  category     = "env"
  key          = each.value.key
  value        = var.applications[each.value.app].client_id
  description  = "managed by Terraform: ${each.value.app}"
}

