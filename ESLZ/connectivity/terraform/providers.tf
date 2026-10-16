terraform {
  required_version = "~> 1.16"

  cloud {
    organization = "4esnok"
    workspaces {
      project = "4esnok_su_azure"
      name    = "4esnok_su_connectivity"
    }
  }

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Remote runs sign in with the workspace's dynamic credentials; local runs use `az login`.
provider "azapi" {
  subscription_id      = local.config.subscription_id # the resource group module uses the provider's subscription
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Only for the Network Manager module (Azure/avm-res-network-networkmanager), which uses azurerm internally.
# Signs in with the workspace's dynamic credentials natively.
provider "azurerm" {
  features {}
  subscription_id                 = local.config.subscription_id
  resource_provider_registrations = "none"
}

# Resolves the group, user and service_principal names in subnet consumers (needs Directory.Read.All).
provider "azuread" {}
