# Read by workloads with `data "tfe_outputs"` (remote_state of the workspace in
# HCP/config.yaml), so they never hardcode platform IDs.
output "resource_group_id" {
  description = "ID of the connectivity resource group."
  value       = module.network.resource_group_id
}

output "subnets" {
  description = "Subnet IDs by \"<vnet>/<subnet>\", e.g. \"cortex/snet-app\" or \"hub/snet-shared\"."
  value       = module.network.subnets
}

output "reservations" {
  description = "Address prefixes reserved in IPAM by \"<spoke>/<name>\", e.g. \"cortex/aks-services\"."
  value       = module.network.reservations
}

output "vnets" {
  description = "VNet IDs and the address space IPAM allocated to them."
  value       = module.network.vnets
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by zone name, e.g. \"privatelink.azurecr.io\"."
  value       = module.network.private_dns_zone_ids
}
