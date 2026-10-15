# Current name of each subscription (Reader is enough)
data "azapi_resource" "subscription" {
  for_each = local.config

  type                   = "Microsoft.Resources/subscriptions@2022-12-01"
  resource_id            = "/subscriptions/${each.value.subscription_id}"
  response_export_values = ["displayName"]
}

output "subscriptions" {
  description = "Per subscription: current name and managed resource groups."
  value = {
    for sub in keys(local.config) : sub => {
      display_name       = data.azapi_resource.subscription[sub].output.displayName
      resource_group_ids = module.subscription[sub].resource_group_resource_ids
    }
  }
}
