output "role_assignment_id" {
  value       = azuread_directory_role_eligibility_schedule_request.this.id
  description = "The ID of the PIM role eligibility schedule request"
}

output "role_name" {
  value       = var.pim_role.role_name
  description = "The name of the assigned role"
}

output "principal_id" {
  value       = local.principal_id
  description = "The principal ID of the assignee"
}
