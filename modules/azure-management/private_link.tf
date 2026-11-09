# Azure Monitor private link scope (AMPLS), from the private_link section of the config: the Log Analytics workspace
# and the Azure Monitor workspace's data collection endpoint (Prometheus ingestion), behind one private endpoint in
# the hub. Microsoft recommends a single AMPLS on the hub of a hub-and-spoke network: the Azure Monitor private DNS
# zones are shared, so every VNet linked to them reaches Azure Monitor through this endpoint.

locals {
  private_link = try(local.config.private_link, { enabled = false })
  ampls_name   = module.naming.names.monitor_private_link_scope.name
}

resource "azurerm_monitor_private_link_scope" "this" {
  count = local.private_link.enabled ? 1 : 0

  name                  = local.ampls_name
  resource_group_name   = local.config.resource_group
  ingestion_access_mode = local.private_link.ingestion_access_mode
  query_access_mode     = local.private_link.query_access_mode
}

resource "azurerm_monitor_private_link_scoped_service" "log_analytics" {
  count = local.private_link.enabled ? 1 : 0

  name                = module.naming.names.operational_insights_workspace.name
  resource_group_name = local.config.resource_group
  scope_name          = azurerm_monitor_private_link_scope.this[0].name
  linked_resource_id  = module.log_analytics.resource_id
}

# The data collection endpoint that Azure creates with the Azure Monitor workspace, in a resource group of its own
resource "azurerm_monitor_private_link_scoped_service" "prometheus" {
  count = local.private_link.enabled && local.prometheus.enabled ? 1 : 0

  name                = azurerm_monitor_workspace.prometheus[0].name
  resource_group_name = local.config.resource_group
  scope_name          = azurerm_monitor_private_link_scope.this[0].name
  linked_resource_id  = azurerm_monitor_workspace.prometheus[0].default_data_collection_endpoint_id
}

# No DNS zone group: Azure Policy adds one that writes the records into the central zones (Deploy-PrivateLink-DNS in
# ESLZ/governance), so this pipeline needs no rights on them. The module doesn't manage zone groups it wasn't given.
module "private_endpoint" {
  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.3.1"
  count   = local.private_link.enabled ? 1 : 0

  name                           = "pep-${local.ampls_name}"
  network_interface_name         = "nic-pep-${local.ampls_name}"
  location                       = local.location
  parent_id                      = local.resource_group_id
  subnet_resource_id             = var.private_endpoint_subnet_id
  private_connection_resource_id = azurerm_monitor_private_link_scope.this[0].id
  subresource_names              = ["azuremonitor"]
  tags                           = try(local.private_link.tags, null)
  enable_telemetry               = false

  # Resources join the scope before the endpoint, so the endpoint's DNS covers them from the start
  depends_on = [
    azurerm_monitor_private_link_scoped_service.log_analytics,
    azurerm_monitor_private_link_scoped_service.prometheus,
  ]
}
