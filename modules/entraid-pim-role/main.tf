# PIM eligible assignment of an Entra ID directory role (requires Entra ID P2)

locals {
  principal_ids = {
    Group            = var.group_ids
    User             = var.user_ids
    ServicePrincipal = var.service_principal_ids
  }
  principal_id = local.principal_ids[var.pim_role.assignment_type][var.pim_role.assignee_name]
}

resource "azuread_directory_role_eligibility_schedule_request" "this" {
  role_definition_id = var.role_template_id
  principal_id       = local.principal_id
  directory_scope_id = "/"
  justification      = "Managed by Terraform"
}
