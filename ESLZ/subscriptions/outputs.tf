output "subscriptions" {
  description = "Per subscription: managed resource groups and user-assigned managed identities."
  value = {
    for sub in keys(local.config) : sub => {
      resource_group_ids             = module.subscription[sub].resource_group_resource_ids
      managed_identity_ids           = module.subscription[sub].umi_resource_ids
      managed_identity_principal_ids = module.subscription[sub].umi_principal_ids
    }
  }
}
