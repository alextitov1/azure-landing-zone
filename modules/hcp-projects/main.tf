# HCP Terraform projects and workspaces from a tier's config.yaml; used by tier 0 and tier 1.

locals {
  workspaces = merge([for p in values(var.projects) : p.workspaces]...)
}

# GitHub App installations named in vcs.github_app_installation; the lookup needs a user token
data "tfe_github_app_installation" "this" {
  for_each = toset([for ws in values(local.workspaces) : ws.vcs.github_app_installation if try(ws.vcs, null) != null])
  name     = each.key
}

# Values of the 1Password references in `secrets:`
module "secrets" {
  source     = "../onepassword-secrets"
  references = toset(flatten([for ws in values(local.workspaces) : values(try(ws.secrets, {}))]))
}

module "project" {
  source   = "../tfe-workspace"
  for_each = var.projects

  organization_name   = var.organization
  project_name        = each.key
  project_description = try(each.value.description, null)

  secret_env_vars = { for name, ws in each.value.workspaces : name => ws.secrets if try(ws.secrets, null) != null }
  secret_values   = module.secrets.values

  workspaces = {
    for name, ws in each.value.workspaces : name => {
      description       = try(ws.description, null)
      terraform_version = try(ws.terraform_version, null)
      auto_apply        = try(ws.auto_apply, null)
      tags              = try(ws.tags, null)
      auto_destroy      = try(ws.auto_destroy, null)
      env_vars          = try(ws.env_vars, null)
      working_directory = try(ws.vcs.working_directory, null)
      trigger_patterns  = try(ws.vcs.trigger_patterns, ["/${ws.vcs.working_directory}/**/*"], null)
      vcs_repo = try(ws.vcs, null) == null ? null : {
        identifier                 = ws.vcs.repo
        branch                     = try(ws.vcs.branch, "main")
        github_app_installation_id = data.tfe_github_app_installation.this[ws.vcs.github_app_installation].id
      }
    }
  }
}

locals {
  workspace_ids = merge([for p in module.project : p.workspace_ids]...)
}

# Here rather than in tfe-workspace, so a workspace can share its state with workspaces of other projects
resource "tfe_workspace_settings" "this" {
  for_each = local.workspaces

  workspace_id   = local.workspace_ids[each.key]
  execution_mode = try(each.value.execution_mode, "remote")

  # State is shared only with the named workspaces, which read it with `data "tfe_outputs"`
  global_remote_state       = false
  remote_state_consumer_ids = [for c in try(each.value.remote_state_consumers, []) : local.workspace_ids[c]]

  lifecycle {
    # Destroying a workspace whose outputs other workspaces read would break them
    precondition {
      condition     = try(each.value.auto_destroy, null) == null || length(try(each.value.remote_state_consumers, [])) == 0
      error_message = "${each.key}: auto_destroy cannot be set on a workspace with remote_state_consumers."
    }
  }
}
