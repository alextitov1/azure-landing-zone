# Managed Prometheus (Azure Monitor workspace) and Azure Managed Grafana, from the prometheus and grafana sections
# of ../config/management.yaml. There are no published Azure Verified Modules for either, so they are plain azurerm
# resources, and every azurerm argument can be set from the config (unset ones keep the provider default).
# Grafana reads Prometheus through its managed identity, and Azure Monitor (metrics and the Log Analytics workspace)
# across the subscription. Users get Grafana roles from ESLZ/subscriptions (Grafana Admin and friends).

locals {
  prometheus = try(local.config.prometheus, { enabled = false })
  grafana    = try(local.config.grafana, { enabled = false })

  grafana_identity        = try(local.grafana.identity, { type = "SystemAssigned" })
  grafana_system_identity = local.grafana.enabled && local.grafana_identity.type == "SystemAssigned"
  grafana_smtp            = try(local.grafana.smtp, null)

  # Data sources: this stack's Prometheus workspace and any others from the config
  grafana_monitor_workspace_ids = concat(
    [for w in azurerm_monitor_workspace.prometheus : w.id],
    try(local.grafana.additional_azure_monitor_workspace_ids, []),
  )
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

  name                          = try(local.prometheus.name, module.naming.names.monitor_workspace.name)
  resource_group_name           = module.resource_group.name
  location                      = try(local.prometheus.location, local.location)
  public_network_access_enabled = try(local.prometheus.public_network_access_enabled, null)
  tags                          = try(local.prometheus.tags, null)

  dynamic "timeouts" {
    for_each = try([local.prometheus.timeouts], [])
    content {
      create = try(timeouts.value.create, null)
      read   = try(timeouts.value.read, null)
      update = try(timeouts.value.update, null)
      delete = try(timeouts.value.delete, null)
    }
  }
}

resource "azurerm_dashboard_grafana" "this" {
  count = local.grafana.enabled ? 1 : 0

  name                                   = try(local.grafana.name, module.naming_grafana[0].names.grafana.name)
  resource_group_name                    = module.resource_group.name
  location                               = local.grafana.location
  grafana_major_version                  = local.grafana.major_version
  sku                                    = try(local.grafana.sku, null)
  sku_size                               = try(local.grafana.sku_size, null)
  zone_redundancy_enabled                = try(local.grafana.zone_redundancy_enabled, null)
  public_network_access_enabled          = try(local.grafana.public_network_access_enabled, null)
  api_key_enabled                        = try(local.grafana.api_key_enabled, null)
  deterministic_outbound_ip_enabled      = try(local.grafana.deterministic_outbound_ip_enabled, null)
  auto_generated_domain_name_label_scope = try(local.grafana.auto_generated_domain_name_label_scope, null)
  tags                                   = try(local.grafana.tags, null)

  identity {
    type         = local.grafana_identity.type
    identity_ids = try(local.grafana_identity.identity_ids, null)
  }

  dynamic "azure_monitor_workspace_integrations" {
    for_each = local.grafana_monitor_workspace_ids
    content {
      resource_id = azure_monitor_workspace_integrations.value
    }
  }

  dynamic "smtp" {
    for_each = local.grafana_smtp == null ? [] : [local.grafana_smtp]
    content {
      enabled                   = try(smtp.value.enabled, null)
      host                      = smtp.value.host
      user                      = smtp.value.user
      password                  = var.grafana_smtp_password
      start_tls_policy          = smtp.value.start_tls_policy
      from_address              = smtp.value.from_address
      from_name                 = try(smtp.value.from_name, null)
      verification_skip_enabled = try(smtp.value.verification_skip_enabled, null)
    }
  }

  dynamic "timeouts" {
    for_each = try([local.grafana.timeouts], [])
    content {
      create = try(timeouts.value.create, null)
      read   = try(timeouts.value.read, null)
      update = try(timeouts.value.update, null)
      delete = try(timeouts.value.delete, null)
    }
  }

  lifecycle {
    precondition {
      condition     = local.grafana_smtp == null || var.grafana_smtp_password != null
      error_message = "grafana.smtp is set, so the variable grafana_smtp_password is required."
    }
  }
}

# Query Prometheus metrics. A user-assigned identity gets its roles where it is created.
resource "azurerm_role_assignment" "grafana_prometheus" {
  count = local.grafana_system_identity && local.prometheus.enabled ? 1 : 0

  scope                = azurerm_monitor_workspace.prometheus[0].id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.this[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# The Azure Monitor data source: platform metrics, and logs in the Log Analytics workspace
resource "azurerm_role_assignment" "grafana_monitoring" {
  count = local.grafana_system_identity ? 1 : 0

  scope                = "/subscriptions/${local.config.subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
