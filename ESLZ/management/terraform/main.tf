# Platform management: the central Log Analytics workspace, from ../config/management.yaml. The one workspace
# for platform and workload logs (ESLZ/management_design.md).

locals {
  config        = yamldecode(file("${path.module}/../config/management.yaml"))
  location      = local.config.location
  log_analytics = local.config.log_analytics
}

# Names: <type>-<workload>-<env>-<region>-<nn>, see ESLZ/README.md
module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"

  suffix          = ["mgmt", local.config.environment, local.config.region_code]
  instance        = local.config.instance
  instance_format = "%02d"
  unique_length   = 0
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = module.naming.names.resource_group.name
  location         = local.location
  enable_telemetry = false
}

# Public ingestion and query (no private link scope). Access is resource-context: whoever can read a resource can
# read its logs here, without rights on the whole workspace.
module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  name                = module.naming.names.operational_insights_workspace.name
  resource_group_name = module.resource_group.name
  location            = local.location
  enable_telemetry    = false

  log_analytics_workspace_sku                             = local.log_analytics.sku
  log_analytics_workspace_retention_in_days               = local.log_analytics.retention_in_days
  log_analytics_workspace_daily_quota_gb                  = local.log_analytics.daily_quota_gb
  log_analytics_workspace_local_authentication_enabled    = local.log_analytics.local_authentication_enabled
  log_analytics_workspace_allow_resource_only_permissions = true
  log_analytics_workspace_internet_ingestion_enabled      = "true"
  log_analytics_workspace_internet_query_enabled          = "true"
}
