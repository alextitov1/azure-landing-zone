# Tier 1: all HCP Terraform projects and workspaces except tier 0 and tier 1.
# One YAML file per project in ./projects. A workspace with a `vcs` block is a pipeline;
# a workspace with an `azure_oidc` block signs in to Azure with dynamic credentials.

locals {
  config = yamldecode(file("${path.module}/../config/organization.yaml"))

  projects = {
    for f in fileset("${path.module}/projects", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/projects/${f}"))
  }

  # Workspaces whose outputs provide Azure OIDC client IDs (azure_oidc.from_workspace)
  oidc_source_workspaces = toset(flatten([
    for p in values(local.projects) : [
      for ws in values(p.workspaces) : ws.azure_oidc.from_workspace
      if try(ws.azure_oidc.from_workspace, null) != null
    ]
  ]))
}

# hcp_oidc output of bootstrap/Azure: { tenant_id, workspaces = { <name> = { plan, apply } } }
data "tfe_outputs" "oidc" {
  for_each = local.oidc_source_workspaces

  organization = local.config.organization
  workspace    = each.key
}

module "project" {
  source   = "../modules/tfe-workspace"
  for_each = local.projects

  organization_name   = local.config.organization
  project_name        = each.value.project
  project_description = try(each.value.description, null)

  workspaces = {
    for name, ws in each.value.workspaces : name => merge(
      { for k, v in ws : k => v if !contains(["vcs", "azure_oidc", "env_vars"], k) },
      {
        terraform_version = try(ws.terraform_version, local.config.terraform_version)
        env_vars = merge(
          try(ws.env_vars, {}),
          try(ws.azure_oidc, null) == null ? {} : {
            for k, v in {
              TFC_AZURE_PROVIDER_AUTH = "true"
              # Explicit values in the YAML win over the source workspace's outputs
              TFC_AZURE_PLAN_CLIENT_ID  = try(ws.azure_oidc.plan_client_id, data.tfe_outputs.oidc[ws.azure_oidc.from_workspace].nonsensitive_values.hcp_oidc.workspaces[name].plan)
              TFC_AZURE_APPLY_CLIENT_ID = try(ws.azure_oidc.apply_client_id, data.tfe_outputs.oidc[ws.azure_oidc.from_workspace].nonsensitive_values.hcp_oidc.workspaces[name].apply)
              ARM_TENANT_ID             = try(ws.azure_oidc.tenant_id, data.tfe_outputs.oidc[ws.azure_oidc.from_workspace].nonsensitive_values.hcp_oidc.tenant_id)
              ARM_SUBSCRIPTION_ID       = try(ws.azure_oidc.subscription_id, null)
            } : k => v if v != null
          }
        )
        working_directory = try(ws.vcs.working_directory, null)
        trigger_patterns  = try(ws.vcs.trigger_patterns, ["/${ws.vcs.working_directory}/**/*"], null)
        vcs_repo = try(ws.vcs, null) == null ? null : {
          identifier     = local.config.github.repo
          branch         = try(ws.vcs.branch, "main")
          oauth_token_id = var.github_oauth_token_id
        }
      }
    )
  }
}
