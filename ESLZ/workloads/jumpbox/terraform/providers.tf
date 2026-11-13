terraform {
  required_version = "~> 1.16"

  # Remote runs: HCP Terraform workspace 4esnok_vs_azure_jumpbox_r2 (HCP/config.yaml).
  cloud {
    organization = "4esnok"
    workspaces {
      project = "4esnok_vs_r2"
      name    = "4esnok_vs_azure_jumpbox_r2"
    }
  }

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }
}

# Signs in with the workspace's dynamic credentials natively. No provider registrations: the pipeline has rights on
# its resource group only.
provider "azurerm" {
  features {}
  subscription_id                 = local.config.subscription_id
  resource_provider_registrations = "none"
}

# Only because the virtual machine module (Azure/avm-res-compute-virtualmachine) requires azapi. Remote runs sign in
# with the workspace's dynamic credentials; local runs use `az login`.
provider "azapi" {
  subscription_id      = local.config.subscription_id
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Reads the outputs of the connectivity workspace. Remote runs use the run's token, which can read the workspaces
# that list 4esnok_vs_azure_jumpbox_r2 in remote_state; local runs use TF_TOKEN_app_terraform_io.
provider "tfe" {}
