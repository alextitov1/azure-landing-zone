# Managed Prometheus (Azure Monitor workspace) and Azure Managed Grafana, from the prometheus and grafana sections
# of the config. There are no published Azure Verified Modules for either, so they are plain azurerm resources, and
# every azurerm argument can be set from the config (unset ones keep the provider default). Grafana reads Prometheus
# and Azure Monitor (metrics and the Log Analytics workspace) with a user-assigned identity that subscription vending
# creates with its roles, because this pipeline can't assign roles.

locals {
  prometheus = try(local.config.prometheus, { enabled = false })
  grafana    = try(local.config.grafana, { enabled = false })

  grafana_smtp = try(local.grafana.smtp, null)

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
  resource_group_name           = local.config.resource_group
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

data "azapi_resource" "grafana_identity" {
  count = local.grafana.enabled ? 1 : 0

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = local.grafana.identity
  parent_id = local.resource_group_id
}

resource "azurerm_dashboard_grafana" "this" {
  count = local.grafana.enabled ? 1 : 0

  name                                   = try(local.grafana.name, module.naming_grafana[0].names.grafana.name)
  resource_group_name                    = local.config.resource_group
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
    type         = "UserAssigned"
    identity_ids = [data.azapi_resource.grafana_identity[0].id]
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
