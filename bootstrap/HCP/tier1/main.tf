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

  # Workspaces whose state holds the Entra ID applications named in azure_oidc (azure_oidc.apps_workspace)
  azure_apps_workspaces = toset(flatten([
    for p in values(local.projects) : [
      for ws in values(p.workspaces) : ws.azure_oidc.apps_workspace if try(ws.azure_oidc, null) != null
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

# Outputs of bootstrap/Azure: tenant_id and applications = { <display name> = { client_id, ... } }
data "tfe_outputs" "azure_apps" {
  for_each = local.azure_apps_workspaces

  organization = local.config.organization
  workspace    = each.key
}

locals {
  azure_apps = { for name, o in data.tfe_outputs.azure_apps : name => o.nonsensitive_values }

  azure_oidc_workspaces = merge([
    for p in values(local.projects) : { for name, ws in p.workspaces : name => ws.azure_oidc if try(ws.azure_oidc, null) != null }
  ]...)

  # Applications named in azure_oidc that apps_workspace has not created yet, e.g. when the same merge adds them
  azure_oidc_missing_apps = {
    for name, oidc in local.azure_oidc_workspaces : name => [
      for app in [oidc.plan_app, oidc.apply_app] : app if !can(local.azure_apps[oidc.apps_workspace].applications[app].client_id)
    ]
  }

  # <workspace name> => TFC_AZURE_* / ARM_* env vars, client IDs looked up by the application names in azure_oidc.
  # A workspace gets them once both applications exist; the run trigger below re-runs tier 1 when they do.
  azure_oidc_env_vars = {
    for name, oidc in local.azure_oidc_workspaces : name => {
      for k, v in {
        TFC_AZURE_PROVIDER_AUTH   = "true"
        TFC_AZURE_PLAN_CLIENT_ID  = local.azure_apps[oidc.apps_workspace].applications[oidc.plan_app].client_id
        TFC_AZURE_APPLY_CLIENT_ID = local.azure_apps[oidc.apps_workspace].applications[oidc.apply_app].client_id
        ARM_TENANT_ID             = local.azure_apps[oidc.apps_workspace].tenant_id
        ARM_SUBSCRIPTION_ID       = try(oidc.subscription_id, null)
      } : k => v if v != null
    } if length(local.azure_oidc_missing_apps[name]) == 0
  }
}

check "azure_oidc_applications" {
  assert {
    condition     = alltrue([for apps in values(local.azure_oidc_missing_apps) : length(apps) == 0])
    error_message = "azure_oidc applications not found in their apps_workspace outputs (Azure credentials are not set until they exist): ${jsonencode({ for k, v in local.azure_oidc_missing_apps : k => v if length(v) > 0 })}"
  }
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

# Re-run tier 1 after each apply of a workspace that holds azure_oidc applications, so a workspace and its
# applications can be added in one merge: that apply creates them, the triggered run sets the TFC_AZURE_* variables.
data "tfe_workspace" "tier1" {
  name         = "hcp-tier1"
  organization = local.config.organization
}

resource "tfe_run_trigger" "azure_apps" {
  for_each = local.azure_apps_workspaces

  workspace_id  = data.tfe_workspace.tier1.id
  sourceable_id = merge([for p in module.project : p.workspace_ids]...)[each.key]
}
