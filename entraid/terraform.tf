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

variable "onepassword_service_account_token" {
  type        = string
  description = "1Password service account token, to store user passwords and client secrets. Set via TF_VAR_onepassword_service_account_token."
  sensitive   = true
}

locals {
  config = yamldecode(file("${path.module}/tenants/${var.tenant}/config.yaml"))
}

provider "azuread" {}

provider "msgraph" {}

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}

provider "azapi" {}

# Each tenant has its own ALZ library (hierarchy, archetypes, policy) for Azure/avm-ptn-alz. The provider loads it
# even when the tenant has no management_groups, so every tenant needs lib/ with at least alz_library_metadata.json.
provider "alz" {
  library_references = [{ custom_url = "${path.root}/tenants/${var.tenant}/lib" }]
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

output "domain_verification_records" {
  value = module.entraid.domain_verification_records
}

output "management_group_ids" {
  value       = try(module.management_groups[0].management_group_resource_ids, {})
  description = "Resource IDs of the management groups from the config"
}
