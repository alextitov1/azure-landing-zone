# Tier 0 of an Entra ID tenant: admin and break-glass users, tier-0 groups, and for a tenant with Azure the
# intermediate root management group with its RBAC and hierarchy settings. Run by bootstrap-azure.sh, which picks
# the tenant and its HCP workspace; see README.md.
terraform {
  cloud {}
}

variable "tenant" {
  type        = string
  description = "Tenant directory under tenants/, e.g. 4esnok_vs. Set via TF_VAR_tenant."

  validation {
    condition     = fileexists("${path.module}/tenants/${var.tenant}/config.yaml")
    error_message = "tenants/${var.tenant}/config.yaml does not exist."
  }

  # The workspace comes from TF_WORKSPACE, not this file, so a stale value would plan one tenant's config against
  # another tenant's state
  validation {
    condition     = startswith(terraform.workspace, "${var.tenant}_")
    error_message = "HCP workspace ${terraform.workspace} is not one of tenant ${var.tenant}."
  }
}

locals {
  config = yamldecode(file("${path.module}/tenants/${var.tenant}/config.yaml"))
}

module "entraid" {
  source = "../../modules/entraid-tenant"

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.entra_id
}

module "intermediate_root_management_group" {
  source = "../../modules/azure-intermediate-root-management-group"
  count  = try(local.config.management_groups, null) == null ? 0 : 1

  tenant_id = local.config.entraid_tenant_id
  config    = local.config.management_groups
  group_ids = module.entraid.group_ids
}

# Read by HCP/config.yaml (`variables:`) to point workspaces at their applications
output "client_ids" {
  value       = { for name, app in module.entraid.applications : name => app.client_id }
  description = "Client IDs of the Entra ID applications, by display name"
}
