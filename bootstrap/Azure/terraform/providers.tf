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
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.6"
    }
  }
}

provider "azuread" {}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}

# Tenant settings that the azuread provider does not cover. Locally it uses the Azure CLI login;
# in HCP Terraform remote runs it uses the workspace's dynamic credentials (OIDC).
provider "msgraph" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}
