# Tier 0: creates the tier-1 pipeline workspace and its identity.
# Runs locally with a user API token; everything else is managed by tier 1.

locals {
  config = yamldecode(file("${path.module}/../config/organization.yaml"))
}

# Requires a user token, which is why this lookup lives in tier 0.
data "tfe_github_app_installation" "this" {
  name = local.config.github.app_installation_name
}

# Organization-level GitHub connection for workspaces created by tier 1. Unlike the GitHub App,
# it can be used with team tokens. Authenticates with a GitHub personal access token.
resource "tfe_oauth_client" "github" {
  name             = "github"
  organization     = local.config.organization
  service_provider = "github"
  api_url          = "https://api.github.com"
  http_url         = "https://github.com"
  oauth_token      = var.github_token
}

# Pipeline identity: the HCP Terraform equivalent of a service principal.
# The free plan cannot create custom teams, so the built-in owners team is used.
data "tfe_team" "owners" {
  name = "owners"
}

# Rotated on the first tier-0 apply after 180 days; the old token stays valid
# for 30 more days, so the pipeline keeps working until that apply happens.
resource "time_rotating" "pipeline_token" {
  rotation_days = 180
}

resource "tfe_team_token" "pipeline" {
  team_id    = data.tfe_team.owners.id
  expired_at = timeadd(time_rotating.pipeline_token.rotation_rfc3339, "720h")

  lifecycle {
    replace_triggered_by = [time_rotating.pipeline_token]
  }
}

module "hcp" {
  source = "../modules/tfe-workspace"

  organization_name   = local.config.organization
  project_name        = "hcp"
  project_description = "HCP Terraform management"

  workspaces = {
    "hcp-tier1" = {
      description       = "Tier 1: manages all other HCP Terraform projects and workspaces"
      execution_mode    = "remote"
      terraform_version = local.config.terraform_version
      auto_apply        = true # merge to main applies; review happens in the PR plan
      working_directory = "bootstrap/HCP/tier1"
      trigger_patterns  = ["/bootstrap/HCP/tier1/**/*", "/bootstrap/HCP/config/**/*", "/bootstrap/HCP/modules/**/*"]
      tags              = { tier = "1" }
      vcs_repo = {
        identifier                 = local.config.github.repo
        branch                     = "main"
        github_app_installation_id = data.tfe_github_app_installation.this.id
      }
    }
  }
}

locals {
  tier1_workspace_id = module.hcp.workspace_ids["hcp-tier1"]
}

resource "tfe_variable" "tier1_tfe_token" {
  workspace_id = local.tier1_workspace_id
  category     = "env"
  key          = "TFE_TOKEN"
  value        = tfe_team_token.pipeline.token
  sensitive    = true
  description  = "owners team token, managed by hcp-tier0"
}

resource "tfe_variable" "tier1_github_oauth_token_id" {
  workspace_id = local.tier1_workspace_id
  category     = "terraform"
  key          = "github_oauth_token_id"
  value        = tfe_oauth_client.github.oauth_token_id
  description  = "GitHub OAuth connection for tier-1 workspaces, managed by hcp-tier0"
}

# 1Password service account (vault azure_t1): tier 1 resolves the `secrets:` references in projects/*.yaml with it
resource "tfe_variable" "tier1_onepassword_token" {
  workspace_id = local.tier1_workspace_id
  category     = "env"
  key          = "OP_SERVICE_ACCOUNT_TOKEN"
  value        = var.tier1_onepassword_token
  sensitive    = true
  description  = "1Password service account op_hcp_rw_t1 (vault azure_t1), managed by hcp-tier0"
}
