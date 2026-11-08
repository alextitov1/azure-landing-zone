output "landing_zones" {
  value = {
    for lz in keys(local.config) : lz => {
      resource_group_ids             = module.subscription[lz].resource_group_resource_ids
      managed_identity_ids           = module.subscription[lz].umi_resource_ids
      managed_identity_principal_ids = module.subscription[lz].umi_principal_ids
    }
  }
  description = "Per landing zone: resource IDs of its resource groups and managed identities, and the identities' principal IDs"
}
