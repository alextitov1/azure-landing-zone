# The tfe provider authenticates with TFE_TOKEN and the onepassword provider with OP_ACCOUNT, set by bootstrap-hcp.sh.
terraform {
  cloud {
    organization = "4esnok"
    workspaces { name = "hcp_tf_bootstrap_r0" }
  }

  required_providers {
    # Reads `secrets:` through the 1Password desktop app for OP_ACCOUNT ("Integrate with 1Password SDKs" must be on)
    onepassword = { source = "1Password/onepassword" } # not a hashicorp/* provider, so it must be declared
  }
}

locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

module "hcp" {
  source = "../../modules/hcp-projects"

  organization = local.config.organization
  projects     = local.config.projects
}
