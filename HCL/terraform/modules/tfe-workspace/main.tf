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

  auto_apply        = each.value.auto_apply
  working_directory = each.value.working_directory
  tag_names         = each.value.tag_names

  dynamic "vcs_repo" {
    for_each = each.value.vcs_repo != null ? [each.value.vcs_repo] : []
    content {
      identifier     = vcs_repo.value.identifier
      branch         = vcs_repo.value.branch
      oauth_token_id = vcs_repo.value.oauth_token_id
    }
  }
}
