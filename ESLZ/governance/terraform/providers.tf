terraform {
  required_version = "~> 1.16"

  # Remote runs: HCP Terraform workspace 4esnok_vs_azure_governance_r1 (HCP/config.yaml).
  cloud {
    organization = "4esnok"
    workspaces {
      project = "4esnok_vs_r1"
      name    = "4esnok_vs_azure_governance_r1"
    }
  }

  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.22"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
  }
}

# Remote runs sign in with the workspace's dynamic credentials; local runs use `az login`.
provider "azapi" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# The ALZ library of this landing zone: hierarchy, archetypes and policy
provider "alz" {
  library_references   = [{ custom_url = "${path.root}/../lib" }]
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Only reads the groups that role assignments name
provider "azuread" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}
