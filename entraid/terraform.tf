# Tier 1 of an Entra ID tenant: day-two users, groups, applications, Conditional Access and governance. Runs only in
# the tenant's HCP Terraform workspace, which sets the tenant (TF_VAR_tenant), the 1Password token
# (OP_SERVICE_ACCOUNT_TOKEN) and Azure dynamic credentials, all from HCP/config.yaml; see README.md.
terraform {
  cloud {} # HCP runs set the workspace; keeps a local init from creating local state

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

variable "tenant" {
  type        = string
  description = "Tenant directory under tenants/, e.g. 4esnok_vs. Set by the workspace's TF_VAR_tenant (HCP/config.yaml)."

  validation {
    condition     = fileexists("${path.module}/tenants/${var.tenant}/config.yaml")
    error_message = "tenants/${var.tenant}/config.yaml does not exist."
  }
}

# Set by HCP Terraform, as the workspace uses dynamic Azure credentials (TFC_AZURE_PROVIDER_AUTH). Required, so a run
# without them fails here. Passed explicitly because msgraph has no built-in HCP support.
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
}

locals {
  config = yamldecode(file("${path.module}/tenants/${var.tenant}/config.yaml"))
}

provider "azuread" {
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

provider "msgraph" {
  use_oidc             = true
  client_id_file_path  = var.tfc_azure_dynamic_credentials.default.client_id_file_path
  oidc_token_file_path = var.tfc_azure_dynamic_credentials.default.oidc_token_file_path
}

module "entraid" {
  source = "../modules/entraid-tenant"

  tenant_id = local.config.entraid_tenant_id
  config    = try(local.config.entra_id, {})
}

output "tenant_id" {
  value = module.entraid.tenant_id
}

output "applications" {
  value       = module.entraid.applications
  description = "Client IDs and service principal object IDs of the Entra ID applications"
}

# Read by HCP/config.yaml (`variables:`) to point workspaces at their applications
output "client_ids" {
  value       = { for name, app in module.entraid.applications : name => app.client_id }
  description = "Client IDs of the Entra ID applications, by display name"
}

output "domain_verification_records" {
  value = module.entraid.domain_verification_records
}
