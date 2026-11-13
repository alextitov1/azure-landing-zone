output "management_group_ids" {
  value       = module.alz.management_group_resource_ids
  description = "Resource IDs of the management groups, by name"
}

output "policy_assignment_principal_ids" {
  value       = module.alz.policy_assignment_identity_ids
  description = "Principal IDs of the policy assignments' managed identities, by \"<management group>/<assignment>\""
}
