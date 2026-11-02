# Tier 1 of an Entra ID tenant: day-two users, groups, applications, Conditional Access, governance and
# management groups. Run by entraid.sh, which picks the tenant and its HCP workspace; see README.md.
terraform {
  cloud {}

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
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    alz = {
      source  = "Azure/alz"
      version = "~> 0.22"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }
}

variable "tenant" {
  type        = string
  description = "Tenant directory under tenants/, e.g. 4esnok_vs. Set via TF_VAR_tenant."

  validation {
    condition     = fileexists("${path.module}/tenants/${var.tenant}/config.yaml")
    error_message = "tenants/${var.tenant}/config.yaml does not exist."
  }
}

# Set by HCP Terraform when the workspace uses dynamic Azure credentials (TFC_AZURE_PROVIDER_AUTH); null for local
# runs, which sign in with `az login`. Passed explicitly because msgraph, azapi and alz have no built-in HCP support.
variable "tfc_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
  description = "Azure dynamic credentials injected by HCP Terraform"
  default     = null
}

variable "onepassword_service_account_token" {
  type        = string
  description = "1Password service account token, to store user passwords and client secrets. Set via TF_VAR_onepassword_service_account_token."
  sensitive   = true
}

locals {
  config = yamldecode(file("${path.module}/tenants/${var.tenant}/config.yaml"))
}

provider "azuread" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

provider "msgraph" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}

provider "azapi" {
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

# Each tenant has its own ALZ library (hierarchy, archetypes, policy) for Azure/avm-ptn-alz. The provider loads it
# even when the tenant has no management_groups, so every tenant needs lib/ with at least alz_library_metadata.json.
provider "alz" {
  library_references   = [{ custom_url = "${path.root}/tenants/${var.tenant}/lib" }]
  use_cli              = var.tfc_azure_dynamic_credentials == null
  use_oidc             = var.tfc_azure_dynamic_credentials != null
  client_id_file_path  = try(var.tfc_azure_dynamic_credentials.default.client_id_file_path, null)
  oidc_token_file_path = try(var.tfc_azure_dynamic_credentials.default.oidc_token_file_path, null)
}

module "entraid" {
  source = "../modules/entraid-tenant"

  tenant_id = local.config.entraid_tenant_id
  config    = try(local.config.entra_id, {})
}

module "hcp_workspace_identity" {
  source = "../modules/hcp-workspace-identity"

  organization = try(local.config.hcp_organization, null)
  config       = try(local.config.entra_id.applications, [])
  applications = module.entraid.applications
}

output "tenant_id" {
  value = module.entraid.tenant_id
}

output "applications" {
  value       = module.entraid.applications
  description = "Client IDs and service principal object IDs of the Entra ID applications"
}

output "domain_verification_records" {
  value = module.entraid.domain_verification_records
}

output "management_group_ids" {
  value       = try(module.management_groups[0].management_group_resource_ids, {})
  description = "Resource IDs of the management groups from the config"
}
