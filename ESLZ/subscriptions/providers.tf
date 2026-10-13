terraform {
  required_version = "~> 1.16"

  # Remote runs: HCP Terraform workspace 4esnok_su_subscriptions (bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml).
  # Locally, `terraform plan` runs a speculative plan there (needs TF_TOKEN_app_terraform_io).
  cloud {
    organization = "4esnok"
    workspaces {
      project = "4esnok_su_azure"
      name    = "4esnok_su_subscriptions"
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
  }
}

# Remote runs sign in with the workspace's dynamic credentials (plan and apply applications); local runs use `az login`.
provider "azapi" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Resolves the group, user and service_principal names in role assignments (needs Directory.Read.All).
provider "azuread" {}
