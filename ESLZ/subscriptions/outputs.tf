output "subscriptions" {
  description = "Per subscription: managed resource groups."
  value = {
    for sub in keys(local.config) : sub => {
      resource_group_ids = module.subscription[sub].resource_group_resource_ids
    }
  }
}
