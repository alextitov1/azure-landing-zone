resource "tfe_project" "this" {
  organization = var.organization_name
  name         = var.project_name
  description  = var.project_description
}

resource "tfe_workspace" "this" {
  for_each = var.workspaces

  name         = each.key
  organization = var.organization_name
  project_id   = tfe_project.this.id
  description  = each.value.description

  terraform_version      = each.value.terraform_version
  auto_apply             = each.value.auto_apply
  auto_apply_run_trigger = each.value.auto_apply # runs started by run triggers follow auto_apply
  working_directory      = each.value.working_directory
  trigger_patterns       = each.value.trigger_patterns
  tags                   = each.value.tags

  auto_destroy_at                = try(each.value.auto_destroy.at, null)
  auto_destroy_activity_duration = try(each.value.auto_destroy.after_inactivity, null)

  dynamic "vcs_repo" {
    for_each = each.value.vcs_repo != null ? [each.value.vcs_repo] : []
    content {
      identifier                 = vcs_repo.value.identifier
      branch                     = vcs_repo.value.branch
      oauth_token_id             = vcs_repo.value.oauth_token_id
      github_app_installation_id = vcs_repo.value.github_app_installation_id
    }
  }
}

resource "tfe_variable" "env" {
  for_each = merge([
    for ws_name, ws in var.workspaces : {
      for key, value in ws.env_vars : "${ws_name}/${key}" => {
        workspace = ws_name
        key       = key
        value     = value
      }
    }
  ]...)

  workspace_id = tfe_workspace.this[each.value.workspace].id
  category     = "env"
  key          = each.value.key
  value        = each.value.value
  description  = "managed by Terraform"
}

# Secrets: for_each runs over the references, which are not secret; the ephemeral values only go to value_wo
resource "tfe_variable" "secret_env" {
  for_each = merge([
    for ws_name, vars in var.secret_env_vars : {
      for key, ref in vars : "${ws_name}/${key}" => { workspace = ws_name, key = key, ref = ref }
    }
  ]...)

  workspace_id = tfe_workspace.this[each.value.workspace].id
  category     = "env"
  key          = each.value.key
  value_wo     = var.secret_values[each.value.ref] # write-only: never in state; changes are detected by the provider
  sensitive    = true
  description  = "managed by Terraform (1Password)"
}
