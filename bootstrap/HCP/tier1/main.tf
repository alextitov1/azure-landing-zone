# Tier 1: all HCP Terraform projects and workspaces except tier 0 and tier 1.
# One YAML file per project in ./projects. A workspace with a `vcs` block is a pipeline;
# a workspace with an `azure_oidc` block signs in to Azure with dynamic credentials;
# `secrets` sets sensitive environment variables from 1Password references (op://<vault>/<item>/<field>).

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

# 1Password references from `secrets:`, parsed into vault, item and field
locals {
  secret_refs = {
    for ref in distinct(flatten([
      for p in values(local.projects) : [for ws in values(p.workspaces) : values(try(ws.secrets, {}))]
    ])) :
    ref => {
      vault = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[0]
      item  = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[1]
      field = regex("^op://([^/]+)/([^/]+)/(.+)$", ref)[2] # built-in field (credential, password, ...) or <section>/<field>
    }
  }
}

data "onepassword_vault" "secrets" {
  for_each = toset([for r in values(local.secret_refs) : r.vault])
  name     = each.key
}

data "onepassword_item" "secrets" {
  for_each = toset([for r in values(local.secret_refs) : "${r.vault}/${r.item}"])
  vault    = data.onepassword_vault.secrets[split("/", each.key)[0]].uuid
  title    = split("/", each.key)[1]
}

locals {
  secret_values = {
    for ref, r in local.secret_refs : ref => (
      length(split("/", r.field)) == 2
      # <section>/<field>: custom field in a named section
      ? one(flatten([
        for s in data.onepassword_item.secrets["${r.vault}/${r.item}"].section : [
          for f in s.field : f.value if s.label == split("/", r.field)[0] && f.label == split("/", r.field)[1]
        ]
      ]))
      # built-in field, e.g. credential or password
      : data.onepassword_item.secrets["${r.vault}/${r.item}"][r.field]
    )
  }
}

# hcp_oidc output of bootstrap/Azure: { tenant_id, workspaces = { <name> = { plan, apply } } }
data "tfe_outputs" "oidc" {
  for_each = local.oidc_source_workspaces

  organization = local.config.organization
  workspace    = each.key
}

locals {
  hcp_oidc = { for ws, out in data.tfe_outputs.oidc : ws => out.nonsensitive_values.hcp_oidc }

  # <workspace name> => TFC_AZURE_* / ARM_* env vars; explicit YAML values win over the source outputs
  azure_oidc_env_vars = merge([
    for p in values(local.projects) : {
      for name, ws in p.workspaces : name => {
        for k, v in {
          TFC_AZURE_PROVIDER_AUTH   = "true"
          TFC_AZURE_PLAN_CLIENT_ID  = try(ws.azure_oidc.plan_client_id, local.hcp_oidc[ws.azure_oidc.from_workspace].workspaces[name].plan)
          TFC_AZURE_APPLY_CLIENT_ID = try(ws.azure_oidc.apply_client_id, local.hcp_oidc[ws.azure_oidc.from_workspace].workspaces[name].apply)
          ARM_TENANT_ID             = try(ws.azure_oidc.tenant_id, local.hcp_oidc[ws.azure_oidc.from_workspace].tenant_id)
          ARM_SUBSCRIPTION_ID       = try(ws.azure_oidc.subscription_id, null)
        } : k => v if v != null
      } if try(ws.azure_oidc, null) != null
    }
  ]...)
}

module "project" {
  source   = "../modules/tfe-workspace"
  for_each = local.projects

  organization_name   = local.config.organization
  project_name        = each.value.project
  project_description = try(each.value.description, null)

  secret_env_vars = {
    for name, ws in each.value.workspaces : name => {
      for key, ref in ws.secrets : key => local.secret_values[ref]
    } if try(ws.secrets, null) != null
  }

  workspaces = {
    for name, ws in each.value.workspaces : name => merge(
      { for k, v in ws : k => v if !contains(["vcs", "azure_oidc", "env_vars", "secrets"], k) },
      {
        terraform_version = try(ws.terraform_version, local.config.terraform_version)
        env_vars          = merge(try(ws.env_vars, {}), try(local.azure_oidc_env_vars[name], {}))
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
