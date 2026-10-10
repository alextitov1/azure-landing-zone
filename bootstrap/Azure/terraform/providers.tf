terraform {
  cloud {
    # organization = "4esnok"

    # workspaces {
    #   name = "entraid_bootstrap"
    # }
  }

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }
}

provider "azuread" {}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}

# Authenticates with TFE_TOKEN; used to set dynamic credential variables on HCP Terraform workspaces.
provider "tfe" {
  hostname = "app.terraform.io"
}
