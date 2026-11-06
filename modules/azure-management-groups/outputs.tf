output "management_group_ids" {
  value       = module.alz.management_group_resource_ids
  description = "Resource IDs of the management groups, by name"
}
