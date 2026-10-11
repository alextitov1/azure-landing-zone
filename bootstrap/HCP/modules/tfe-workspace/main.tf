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

  terraform_version = each.value.terraform_version
  auto_apply        = each.value.auto_apply
  working_directory = each.value.working_directory
  trigger_patterns  = each.value.trigger_patterns
  tags              = each.value.tags

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

resource "tfe_workspace_settings" "this" {
  for_each = var.workspaces

  workspace_id   = tfe_workspace.this[each.key].id
  execution_mode = each.value.execution_mode
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
  description  = "managed by hcp-tier1"
}

# Secrets (e.g. from 1Password). Keys are not secret, so they are unmarked for for_each.
locals {
  secret_env_vars = merge([
    for ws_name, vars in var.secret_env_vars : {
      for key, value in vars : "${ws_name}/${key}" => { workspace = ws_name, key = key, value = value }
    }
  ]...)
}

resource "tfe_variable" "secret_env" {
  for_each = toset(nonsensitive(keys(local.secret_env_vars)))

  workspace_id = tfe_workspace.this[local.secret_env_vars[each.key].workspace].id
  category     = "env"
  key          = nonsensitive(local.secret_env_vars[each.key].key)
  value        = local.secret_env_vars[each.key].value
  sensitive    = true
  description  = "managed by hcp-tier1 (1Password)"
}
