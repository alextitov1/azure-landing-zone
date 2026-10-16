# Read by workloads with `data "tfe_outputs"` (remote_state_consumers of the workspace in
# bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml), so they never hardcode platform IDs.
output "resource_group_id" {
  description = "ID of the connectivity resource group."
  value       = module.resource_group.resource_id
}

output "subnets" {
  description = "Subnet IDs by \"<vnet>/<subnet>\", e.g. \"cortex/snet-app\" or \"hub/snet-shared\"."
  value = merge(
    { for name, s in module.hub.subnets : "hub/${name}" => s.resource_id },
    merge([for spoke, m in module.spoke : { for name, s in m.subnets : "${spoke}/${name}" => s.resource_id }]...),
  )
}

output "vnets" {
  description = "VNet IDs and the address space IPAM allocated to them."
  value = merge(
    { hub = { id = module.hub.resource_id, address_space = module.hub.address_spaces } },
    { for k, m in module.spoke : k => { id = m.resource_id, address_space = m.address_spaces } },
  )
}
