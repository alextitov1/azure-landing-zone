output "subscriptions" {
  description = "Per subscription: current name, managed resource groups, and resource groups that exist but are not in the YAML."
  value = {
    for sub, c in local.config : sub => {
      display_name       = data.azapi_resource.subscription[sub].output.displayName
      resource_group_ids = module.subscription[sub].resource_group_resource_ids
      unmanaged_resource_groups = {
        for name, g in local.existing_resource_groups[sub] : name => g.location
        if !contains(keys(c.resource_groups), name)
      }
    }
  }
}
