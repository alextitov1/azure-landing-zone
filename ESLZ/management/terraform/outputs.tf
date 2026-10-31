# Read by workloads with `data "tfe_outputs"` (remote_state_consumers of the workspace in
# HCP/config.yaml), so they never hardcode platform IDs.
output "resource_group_id" {
  description = "ID of the management resource group."
  value       = module.resource_group.resource_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace, for diagnostic settings and data collection rules."
  value       = module.log_analytics.resource_id
}

# The module's resource output is sensitive as a whole (it holds the shared keys); the customer ID is not a secret.
output "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) ID of the central Log Analytics workspace, for KQL queries and agents."
  value       = nonsensitive(module.log_analytics.resource.workspace_id)
}

output "azure_monitor_workspace_id" {
  description = "Resource ID of the Azure Monitor workspace (managed Prometheus), for AKS metrics; null when disabled."
  value       = try(azurerm_monitor_workspace.prometheus[0].id, null)
}

output "grafana_endpoint" {
  description = "URL of Azure Managed Grafana; null when disabled."
  value       = try(azurerm_dashboard_grafana.this[0].endpoint, null)
}
