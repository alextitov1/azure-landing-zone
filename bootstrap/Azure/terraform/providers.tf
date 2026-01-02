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
  }
}

provider "azuread" {}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}
