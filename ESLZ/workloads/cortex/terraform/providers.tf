terraform {
  required_version = "~> 1.16"

  # Remote runs: HCP Terraform workspace 4esnok_su_cortex (bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml).
  cloud {
    organization = "4esnok"
    workspaces {
      project = "4esnok_su_azure"
      name    = "4esnok_su_cortex"
    }
  }

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }
}

# Remote runs sign in with the workspace's dynamic credentials; local runs use `az login`.
provider "azapi" {
  subscription_id      = local.config.subscription_id
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Reads the outputs of the platform workspaces. Remote runs use the run's token, which can read the workspaces
# that list 4esnok_su_cortex in remote_state_consumers; local runs use TF_TOKEN_app_terraform_io.
provider "tfe" {}
