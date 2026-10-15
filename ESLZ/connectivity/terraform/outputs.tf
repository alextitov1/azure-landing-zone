output "vnets" {
  description = "VNet IDs and the address space IPAM allocated to them."
  value = merge(
    { hub = { id = module.hub.resource_id, address_space = module.hub.address_spaces } },
    { for k, m in module.spoke : k => { id = m.resource_id, address_space = m.address_spaces } },
  )
}
