# Tier 1 (hcp_tf_workspaces_r1): the projects and workspaces in config.yaml; see README.md for the schema.
# Works like tier 0 (bootstrap/HCP), but runs in HCP on merge to main, as a 1Password service account.

# Credentials come from the environment, set on the workspace by hcp_tf_bootstrap_r0:
# TFE_TOKEN (user token; only user tokens can link workspaces through the GitHub App) and
# OP_SERVICE_ACCOUNT_TOKEN (1Password service account).
terraform {
  required_providers {
    onepassword = { source = "1Password/onepassword" } # not a hashicorp/* provider, so it must be declared
  }
}

locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

module "hcp" {
  source = "../modules/hcp-projects"

  organization = local.config.organization
  projects     = local.config.projects
}
