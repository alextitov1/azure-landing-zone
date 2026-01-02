# PIM eligible role assignment for Entra ID directory roles

data "azuread_directory_role_templates" "all" {}

locals {
  # Find the role template ID for the specified role name
  role_template_id = [
    for role in data.azuread_directory_role_templates.all.role_templates :
    role.object_id if role.display_name == var.pim_role.role_name
  ][0]

  # Determine principal ID based on assignment type
  principal_id = var.pim_role.assignment_type == "Group" ? var.group_ids[var.pim_role.assignee_name] : var.user_ids[var.pim_role.assignee_name]
}

# Activate the directory role (required before assignment)
resource "azuread_directory_role" "this" {
  template_id = local.role_template_id
}

resource "azuread_directory_role" "this1" {
  display_name = var.pim_role.role_name
}

# Create PIM eligible assignment
resource "azuread_directory_role_eligibility_schedule_request" "this" {
  role_definition_id = azuread_directory_role.this1.template_id
  principal_id       = local.principal_id
  directory_scope_id = "/"
  justification      = "Managed by Terraform"
}
