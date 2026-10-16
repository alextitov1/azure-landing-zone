output "resource_group_id" {
  description = "ID of the cortex resource group."
  value       = local.resource_group_id
}

output "subnet_id" {
  description = "ID of the cortex subnet, from the connectivity workspace."
  value       = local.subnet_id
}
