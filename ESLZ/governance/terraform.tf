# Management groups below the intermediate root mg-4esnok, with Azure Policy and Azure RBAC on them, from config.yaml,
# and subscription vending, from subscriptions/. Runs only in the HCP Terraform workspace
# 4esnok_vs_azure_governance_r1, which sets the Azure dynamic credentials (HCP/config.yaml); see README.md.
terraform {
  required_version = "~> 1.16"

  cloud {} # HCP runs set the workspace; keeps a local init from creating local state

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

# Set by HCP Terraform, as the workspace uses dynamic Azure credentials (TFC_AZURE_PROVIDER_AUTH). Required, so a run
# without them fails here. Passed explicitly because azapi and alz have no built-in HCP support.
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
  config = yamldecode(file("${path.module}/config.yaml"))
  oidc   = var.tfc_azure_dynamic_credentials.default

  landing_zones = {
    for f in fileset("${path.module}/subscriptions", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/subscriptions/${f}"))
  }
}

provider "azapi" {
  use_oidc             = true
  client_id_file_path  = local.oidc.client_id_file_path
  oidc_token_file_path = local.oidc.oidc_token_file_path
}

provider "alz" {
  library_references = [
    for ref in local.config.alz_library_references : {
      custom_url = try("${path.module}/${ref.custom_url}", null)
      path       = try(ref.path, null)
      ref        = try(ref.ref, null)
    }
  ]

  use_oidc             = true
  client_id_file_path  = local.oidc.client_id_file_path
  oidc_token_file_path = local.oidc.oidc_token_file_path
}

# Only reads the groups and service principals that role assignments name
provider "azuread" {
  use_oidc             = true
  client_id_file_path  = local.oidc.client_id_file_path
  oidc_token_file_path = local.oidc.oidc_token_file_path
}

module "management_groups" {
  source = "../../modules/azure-management-groups"

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.management_groups
}

module "subscription_vending" {
  source = "../../modules/azure-subscription-vending"

  landing_zones        = local.landing_zones
  management_group_ids = module.management_groups.management_group_ids
}

output "management_group_ids" {
  value       = module.management_groups.management_group_ids
  description = "Resource IDs of the management groups, by name"
}

output "landing_zones" {
  value       = module.subscription_vending.landing_zones
  description = "Per landing zone: resource IDs of its resource groups and managed identities, and the identities' principal IDs"
}
