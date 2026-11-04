output "management_group_ids" {
  value       = module.management_groups.management_group_resource_ids
  description = "Resource IDs of the management groups from the config"
}
