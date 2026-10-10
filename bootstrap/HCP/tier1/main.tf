# Tier 1: all HCP Terraform projects and workspaces except tier 0 and tier 1.
# One YAML file per project in ./projects. A workspace with a `vcs` block is a pipeline.

locals {
  config = yamldecode(file("${path.module}/../config/organization.yaml"))

  projects = {
    for f in fileset("${path.module}/projects", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/projects/${f}"))
  }
}

module "project" {
  source   = "../modules/tfe-workspace"
  for_each = local.projects

  organization_name   = local.config.organization
  project_name        = each.value.project
  project_description = try(each.value.description, null)

  workspaces = {
    for name, ws in each.value.workspaces : name => merge(
      { for k, v in ws : k => v if k != "vcs" },
      {
        terraform_version = try(ws.terraform_version, local.config.terraform_version)
        working_directory = try(ws.vcs.working_directory, null)
        trigger_patterns  = try(ws.vcs.trigger_patterns, ["${ws.vcs.working_directory}/**"], null)
        vcs_repo = try(ws.vcs, null) == null ? null : {
          identifier                 = local.config.github.repo
          branch                     = try(ws.vcs.branch, "main")
          github_app_installation_id = var.github_app_installation_id
        }
      }
    )
  }
}
