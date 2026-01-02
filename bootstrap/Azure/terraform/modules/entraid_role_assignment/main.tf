# Permanent (active) Entra ID directory role assignment

locals {
  # Determine principal ID based on assignment type
  principal_id = var.role_assignment.assignment_type == "Group" ? var.group_ids[var.role_assignment.assignee_name] : var.user_ids[var.role_assignment.assignee_name]
}

# Create permanent role assignment (role is activated at root level)
resource "azuread_directory_role_assignment" "this" {
  role_id             = var.role_id
  principal_object_id = local.principal_id
}
