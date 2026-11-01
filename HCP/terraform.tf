# Tier 1 (hcp_tf_workspaces_r1): the projects and workspaces in config.yaml; see README.md for the schema.
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
