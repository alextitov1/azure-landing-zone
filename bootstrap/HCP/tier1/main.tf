# Tier 1: all HCP Terraform projects and workspaces except tier 0 and tier 1.
# One YAML file per project in ./projects. A workspace with a `vcs` block is a pipeline;
# a workspace with an `azure_oidc` block signs in to Azure with dynamic credentials.

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
      { for k, v in ws : k => v if !contains(["vcs", "azure_oidc"], k) },
      {
        terraform_version = try(ws.terraform_version, local.config.terraform_version)
        env_vars = try(ws.azure_oidc, null) == null ? {} : merge(
          {
            TFC_AZURE_PROVIDER_AUTH   = "true"
            TFC_AZURE_PLAN_CLIENT_ID  = ws.azure_oidc.plan_client_id
            TFC_AZURE_APPLY_CLIENT_ID = ws.azure_oidc.apply_client_id
            ARM_TENANT_ID             = ws.azure_oidc.tenant_id
          },
          try(ws.azure_oidc.subscription_id, null) == null ? {} : { ARM_SUBSCRIPTION_ID = ws.azure_oidc.subscription_id }
        )
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
