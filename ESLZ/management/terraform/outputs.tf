# Read by workloads with `data "tfe_outputs"` (remote_state of the workspace in
# HCP/config.yaml), so they never hardcode platform IDs.
output "resource_group_id" {
  description = "ID of the management resource group."
  value       = module.management.resource_group_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace, for diagnostic settings and data collection rules."
  value       = module.management.log_analytics_workspace_id
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) ID of the central Log Analytics workspace, for KQL queries and agents."
  value       = module.management.log_analytics_workspace_customer_id
}

output "azure_monitor_workspace_id" {
  description = "Resource ID of the Azure Monitor workspace (managed Prometheus), for AKS metrics; null when disabled."
  value       = module.management.azure_monitor_workspace_id
}

output "grafana_endpoint" {
  description = "URL of Azure Managed Grafana; null when disabled."
  value       = module.management.grafana_endpoint
}

output "otlp_endpoints" {
  description = "OTLP URLs for the traces, logs and metrics exporters; null when disabled."
  value       = module.management.otlp_endpoints
}

output "otlp_data_collection_rule_id" {
  description = "Resource ID of the OTLP data collection rule, the scope of a sender's Monitoring Metrics Publisher role; null when disabled."
  value       = module.management.otlp_data_collection_rule_id
}

output "otlp_application_insights_id" {
  description = "Resource ID of the Application Insights resource the OTLP telemetry is linked to; null when disabled."
  value       = module.management.otlp_application_insights_id
}

output "private_link_scope_id" {
  description = "Resource ID of the Azure Monitor private link scope, for data collection endpoints that must join it; null when disabled."
  value       = module.management.private_link_scope_id
}
