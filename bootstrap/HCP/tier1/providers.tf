terraform {
  required_version = "~> 1.16"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.3"
    }
  }
}

# Authenticates with TFE_TOKEN (pipeline team token), set on the workspace by hcp-tier0.
provider "tfe" {
  hostname     = "app.terraform.io"
  organization = local.config.organization
}

# Reads the secrets referenced in projects/*.yaml (`secrets:`). Authenticates with OP_SERVICE_ACCOUNT_TOKEN,
# a 1Password service account (vault azure_t1) set on the workspace by hcp-tier0.
provider "onepassword" {}
