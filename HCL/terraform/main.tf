locals {
  organization_name = "4esnok"
  project_name      = "4esnok_su_azure"
  workspaces = {
    "4esnok_su_entraid_bootstrap" = {
      description    = "Entraid tear 0 settings"
      tag_names      = ["dev", "azure"]
      execution_mode = "remote"
    }
    "4esnok_su_subscriptions" = {
      description    = "subscription management workspace"
      tag_names      = ["prod", "azure"]
      execution_mode = "remote"
      auto_apply     = false
    }
  }
}

module "project_network" {
  source = "./modules/tfe-workspace"

  organization_name   = local.organization_name
  project_name        = local.project_name
  project_description = "Core network infrastructure project"

  workspaces = local.workspaces
}
