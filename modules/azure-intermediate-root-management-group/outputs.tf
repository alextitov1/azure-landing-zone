output "management_group_id" {
  value       = azapi_resource.intermediate_root.id
  description = "Resource ID of the intermediate root management group"
}

output "role_assignment_ids" {
  value       = { for key, ra in azapi_resource.intermediate_root_role_assignment : key => ra.id }
  description = "Resource IDs of the role assignments on the intermediate root, by <role>|<group>"
}
