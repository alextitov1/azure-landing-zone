# Tier 0 of the 4esnok_vs tenant: admin and break-glass users, tier-0 groups, and the intermediate root management
# group with its RBAC and hierarchy settings. See ../README.md.
terraform {
  cloud {
    organization = "4esnok"
    workspaces { name = "4esnok_vs_azure_bootstrap_r0" }
  }
}

locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

module "entraid" {
  source = "../../../modules/entraid-tenant"

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.entra_id
}

module "intermediate_root_management_group" {
  source = "../../../modules/azure-intermediate-root-management-group"

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.management_groups
  group_ids = module.entraid.group_ids
}
