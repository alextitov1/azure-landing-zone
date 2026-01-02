output "assignment_id" {
  value       = azuread_directory_role_assignment.this.id
  description = "The ID of the role assignment"
}

output "role_name" {
  value       = var.role_assignment.role_name
  description = "The name of the assigned role"
}

output "principal_id" {
  value       = local.principal_id
  description = "The principal ID of the assignee"
}
