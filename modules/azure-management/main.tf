# Platform management of ESLZ/management, from its config/management.yaml: the central Log Analytics workspace, the
# one workspace for platform and workload logs (ESLZ/management_design.md). Prometheus and Grafana are in
# observability.tf, OTLP ingestion in otlp.tf, the Azure Monitor private link scope in private_link.tf.

locals {
  config            = var.config
  location          = local.config.location
  resource_group_id = data.azapi_resource.resource_group.id
  log_analytics     = local.config.log_analytics
}

# Created by subscription vending in ESLZ/governance, which grants this workspace its roles on it
data "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.config.resource_group
  parent_id = "/subscriptions/${local.config.subscription_id}"
}

# Names: <type>-<workload>-<env>-<region>-<nn>, see ESLZ/README.md
module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"

  suffix               = ["mgmt", local.config.environment, local.config.region_code]
  instance             = local.config.instance
  instance_format      = "%02d"
  unique_length        = 0
  custom_override_file = "${path.module}/naming-overrides.json"
}

# Ingestion and query each public or through the private link scope only (log_analytics in the config). Access is
# resource-context: whoever can read a resource can read its logs here, without rights on the whole workspace.
module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  name                = module.naming.names.operational_insights_workspace.name
  resource_group_name = local.config.resource_group
  location            = local.location
  enable_telemetry    = false

  log_analytics_workspace_sku                             = local.log_analytics.sku
  log_analytics_workspace_retention_in_days               = local.log_analytics.retention_in_days
  log_analytics_workspace_daily_quota_gb                  = local.log_analytics.daily_quota_gb
  log_analytics_workspace_local_authentication_enabled    = local.log_analytics.local_authentication_enabled
  log_analytics_workspace_allow_resource_only_permissions = true
  log_analytics_workspace_internet_ingestion_enabled      = tostring(local.log_analytics.internet_ingestion_enabled)
  log_analytics_workspace_internet_query_enabled          = tostring(local.log_analytics.internet_query_enabled)
}
