# Tier 0 of the 4esnok_mail Entra ID tenant: admin and break-glass users, tier-0 groups. See ../README.md.
terraform {
  cloud {
    organization = "4esnok"
    workspaces { name = "4esnok_mail_entraid_bootstrap_r0" }
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
