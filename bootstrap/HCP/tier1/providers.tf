terraform {
  required_version = "~> 1.16"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }
}

# Authenticates with TFE_TOKEN (pipeline team token), set on the workspace by hcp-tier0.
provider "tfe" {
  hostname     = "app.terraform.io"
  organization = local.config.organization
}
