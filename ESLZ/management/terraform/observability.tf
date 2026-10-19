# Managed Prometheus (Azure Monitor workspace) and Azure Managed Grafana, from the prometheus and grafana sections
# of ../config/management.yaml. There are no Azure Verified Modules for either, so they are plain azurerm resources.
# Grafana reads Prometheus through its managed identity, and Azure Monitor (metrics and the Log Analytics workspace)
# across the subscription. Users get Grafana roles from ESLZ/subscriptions (Grafana Admin and friends).

locals {
  prometheus = try(local.config.prometheus, { enabled = false })
  grafana    = try(local.config.grafana, { enabled = false })
}

# Grafana is not offered in every region, so it has its own region code
module "naming_grafana" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
  count   = local.grafana.enabled ? 1 : 0

  suffix               = ["mgmt", local.config.environment, local.grafana.region_code]
  instance             = local.config.instance
  instance_format      = "%02d"
  unique_length        = 0
  custom_override_file = "${path.module}/naming-overrides.json"
}

# Free; Prometheus ingestion and queries are billed per sample. Metrics are kept for 18 months.
resource "azurerm_monitor_workspace" "prometheus" {
  count = local.prometheus.enabled ? 1 : 0

  name                = module.naming.names.monitor_workspace.name
  resource_group_name = module.resource_group.name
  location            = local.location
}

resource "azurerm_dashboard_grafana" "this" {
  count = local.grafana.enabled ? 1 : 0

  name                          = module.naming_grafana[0].names.grafana.name
  resource_group_name           = module.resource_group.name
  location                      = local.grafana.location
  grafana_major_version         = local.grafana.major_version
  sku                           = "Standard"
  public_network_access_enabled = local.grafana.public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }

  # Adds the Prometheus data source
  dynamic "azure_monitor_workspace_integrations" {
    for_each = azurerm_monitor_workspace.prometheus
    content {
      resource_id = azure_monitor_workspace_integrations.value.id
    }
  }
}

# Query Prometheus metrics
resource "azurerm_role_assignment" "grafana_prometheus" {
  count = local.grafana.enabled && local.prometheus.enabled ? 1 : 0

  scope                = azurerm_monitor_workspace.prometheus[0].id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.this[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# The Azure Monitor data source: platform metrics, and logs in the Log Analytics workspace
resource "azurerm_role_assignment" "grafana_monitoring" {
  count = local.grafana.enabled ? 1 : 0

  scope                = "/subscriptions/${local.config.subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
