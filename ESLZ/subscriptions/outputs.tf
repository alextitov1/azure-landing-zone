output "subscriptions" {
  description = "Per subscription: current name and managed resource groups."
  value = {
    for sub in keys(local.config) : sub => {
      display_name       = data.azapi_resource.subscription[sub].output.displayName
      resource_group_ids = module.subscription[sub].resource_group_resource_ids
    }
  }
}
