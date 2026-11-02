# HCP Terraform projects and workspaces from a tier's config.yaml; used by tier 0 and tier 1.

locals {
  workspaces = merge([for p in values(var.projects) : p.workspaces]...)

  # `variables:` of every workspace, "<workspace>/<key>" => value; a tfe://<workspace>/<output>[/<key>] value is a
  # reference to another workspace's output, split into its parts
  variables = merge([
    for ws_name, ws in local.workspaces : {
      for key, value in try(ws.variables, {}) : "${ws_name}/${key}" => {
        workspace = ws_name
        key       = key
        value     = tostring(value)
        ref       = startswith(tostring(value), "tfe://") ? split("/", trimprefix(tostring(value), "tfe://")) : null
      }
    }
  ]...)

  output_workspaces = toset([for v in values(local.variables) : v.ref[0] if v.ref != null])
}

# Only the referenced workspaces that exist: one created in this run has no outputs yet, so it is read on a later run
data "tfe_workspace_ids" "outputs" {
  count = length(local.output_workspaces) > 0 ? 1 : 0

  names        = local.output_workspaces
  organization = var.organization
}

# Read with the provider's token, so the workspaces don't need to share their state with this one
data "tfe_outputs" "this" {
  for_each = try(data.tfe_workspace_ids.outputs[0].ids, {})

  organization = var.organization
  workspace    = each.key
}

locals {
  # null when the workspace, output or key doesn't exist (yet), or the output is sensitive. Each branch converts to a
  # string itself: HCL unifies the types of both branches, and an object output next to a string fails that.
  variable_values = {
    for k, v in local.variables : k => (
      v.ref == null ? v.value :
      length(v.ref) == 2 ? try(tostring(data.tfe_outputs.this[v.ref[0]].nonsensitive_values[v.ref[1]]), null) :
      length(v.ref) == 3 ? try(tostring(data.tfe_outputs.this[v.ref[0]].nonsensitive_values[v.ref[1]][v.ref[2]]), null) :
      null
    )
  }

  unresolved_variables = [for k, v in local.variables : "${k} = ${v.value}" if local.variable_values[k] == null]
}

# A warning rather than an error, so a workspace and the workspace that creates its values can be added in one merge;
# the run trigger below sets the variable once the values exist
check "workspace_variables" {
  assert {
    condition     = length(local.unresolved_variables) == 0
    error_message = "Not set, the output is missing or sensitive: ${join(", ", local.unresolved_variables)}"
  }
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

  organization_name     = var.organization
  project_name          = each.key
  project_description   = try(each.value.description, null)
  project_variable_sets = try(each.value.variable_sets, [])

  secret_env_vars = { for name, ws in each.value.workspaces : name => ws.secrets if try(ws.secrets, null) != null }
  secret_values   = module.secrets.values

  workspaces = {
    for name, ws in each.value.workspaces : name => {
      description       = try(ws.description, null)
      terraform_version = try(ws.terraform_version, null)
      auto_apply        = try(ws.auto_apply, null)
      tags              = try(ws.tags, null)
      auto_destroy      = try(ws.auto_destroy, null)
      env_vars = {
        for k, v in local.variables : v.key => local.variable_values[k]
        if v.workspace == name && local.variable_values[k] != null
      }
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

  # Not shared unless remote_state says so; the named workspaces read it with `data "tfe_outputs"`
  global_remote_state  = try(each.value.remote_state.share_with, null) == "organization"
  project_remote_state = try(each.value.remote_state.share_with, null) == "project"
  remote_state_consumer_ids = (
    contains(["organization", "project"], try(each.value.remote_state.share_with, "")) ? null :
    [for c in try(each.value.remote_state.workspaces, []) : local.workspace_ids[c]]
  )

  lifecycle {
    precondition {
      condition     = contains(["organization", "project", "workspaces", ""], try(each.value.remote_state.share_with, ""))
      error_message = "${each.key}: remote_state.share_with must be organization, project or workspaces."
    }
    precondition {
      condition     = try(each.value.remote_state.share_with, null) == "workspaces" || length(try(each.value.remote_state.workspaces, [])) == 0
      error_message = "${each.key}: remote_state.workspaces needs share_with: workspaces."
    }
    # Destroying a workspace whose outputs other workspaces read would break them
    precondition {
      condition     = try(each.value.auto_destroy, null) == null || try(each.value.remote_state, null) == null
      error_message = "${each.key}: auto_destroy cannot be set on a workspace with remote_state."
    }
  }
}

# Re-runs the workspace running this configuration after each apply of a workspace it reads outputs from, so a
# variable that was missing gets set without a new merge
data "tfe_workspace" "run_trigger" {
  count = var.run_trigger_workspace == null ? 0 : 1

  name         = var.run_trigger_workspace
  organization = var.organization
}

resource "tfe_run_trigger" "outputs" {
  for_each = var.run_trigger_workspace == null ? toset([]) : toset([for w in local.output_workspaces : w if contains(keys(local.workspaces), w)])

  workspace_id  = data.tfe_workspace.run_trigger[0].id
  sourceable_id = local.workspace_ids[each.key]
}
