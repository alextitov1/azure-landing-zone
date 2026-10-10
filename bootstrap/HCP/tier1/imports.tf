# One-off: adopt objects created by the legacy 4esnok_workspaces configuration.
# Remove this file after the first successful apply.

import {
  to = module.project["4esnok_su_azure"].tfe_project.this
  id = "prj-DpqfSZUS9d8tYycP"
}

import {
  for_each = toset(["4esnok_su_entraid_bootstrap", "4esnok_su_subscriptions"])
  to       = module.project["4esnok_su_azure"].tfe_workspace.this[each.key]
  id       = "4esnok/${each.key}"
}

import {
  for_each = toset(["4esnok_su_entraid_bootstrap", "4esnok_su_subscriptions"])
  to       = module.project["4esnok_su_azure"].tfe_workspace_settings.this[each.key]
  id       = "4esnok/${each.key}"
}
