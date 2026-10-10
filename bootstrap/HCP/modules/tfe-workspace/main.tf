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
      github_app_installation_id = vcs_repo.value.github_app_installation_id
    }
  }
}

resource "tfe_workspace_settings" "this" {
  for_each = var.workspaces

  workspace_id   = tfe_workspace.this[each.key].id
  execution_mode = each.value.execution_mode
}
