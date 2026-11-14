# OTLP ingestion, from the otlp section of the config: a data collection endpoint that receives OpenTelemetry
# signals, and a data collection rule that routes logs and traces to the Log Analytics workspace and metrics to the
# Azure Monitor workspace. The rule follows Microsoft's template for direct OTLP ingestion, without its Application
# Insights reference:
# https://learn.microsoft.com/azure/azure-monitor/containers/opentelemetry-protocol-ingestion

locals {
  otlp = try(local.config.otlp, { enabled = false })

  # Azure Monitor defines the log and trace streams; only the metrics stream is named by the rule's owner
  otlp_log_streams = ["Microsoft-OTel-Logs"]
  otlp_trace_streams = [
    "Microsoft-OTel-Traces-Spans",
    "Microsoft-OTel-Traces-Events",
    "Microsoft-OTel-Traces-Resources",
  ]

  # Traces go to the logs endpoint: only metrics have a host of their own
  otlp_rule_path = local.otlp.enabled ? "datacollectionRules/${module.otlp_rule[0].resource.output.properties.immutableId}/streams" : null
  otlp_endpoints = local.otlp.enabled ? {
    traces  = "${module.otlp_endpoint[0].logs_ingestion_endpoint}/${local.otlp_rule_path}/Microsoft-OTLP-Traces/otlp/v1/traces"
    logs    = "${module.otlp_endpoint[0].logs_ingestion_endpoint}/${local.otlp_rule_path}/Microsoft-OTLP-Logs/otlp/v1/logs"
    metrics = "${module.otlp_endpoint[0].metrics_ingestion_endpoint}/${local.otlp_rule_path}/${local.otlp.metrics_stream}/otlp/v1/metrics"
  } : null
}

# The rule is named after its workload, so the rules that follow it (VM Insights, ...) get names of their own
module "naming_otlp" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
  count   = local.otlp.enabled ? 1 : 0

  suffix               = ["otlp", local.config.environment, local.config.region_code]
  instance             = local.config.instance
  instance_format      = "%02d"
  unique_length        = 0
  custom_override_file = "${path.module}/naming-overrides.json"
}

module "otlp_endpoint" {
  source  = "Azure/avm-res-insights-datacollectionendpoint/azurerm"
  version = "0.2.0"
  count   = local.otlp.enabled ? 1 : 0

  name                  = module.naming.names.data_collection_endpoint.name
  parent_id             = local.resource_group_id
  location              = local.location
  description           = "OTLP ingestion"
  public_network_access = local.otlp.public_network_access ? "Enabled" : "Disabled"
  tags                  = try(local.otlp.tags, null)
  enable_telemetry      = false
}

module "otlp_rule" {
  source  = "Azure/avm-res-insights-datacollectionrule/azurerm"
  version = "0.1.0"
  count   = local.otlp.enabled ? 1 : 0

  name                        = module.naming_otlp[0].names.data_collection_rule.name
  parent_id                   = local.resource_group_id
  location                    = local.location
  description                 = "OTLP logs and traces to Log Analytics, metrics to the Azure Monitor workspace"
  data_collection_endpoint_id = module.otlp_endpoint[0].resource_id
  tags                        = try(local.otlp.tags, null)
  enable_telemetry            = false

  direct_data_sources = {
    otel_logs = [{
      name                            = "otelLogs"
      streams                         = local.otlp_log_streams
      enrich_with_resource_attributes = ["*"]
    }]
    otel_traces = [{
      name                            = "otelTraces"
      streams                         = local.otlp_trace_streams
      enrich_with_resource_attributes = ["*"]
    }]
    otel_metrics = [{
      name                            = "otelMetrics"
      streams                         = [local.otlp.metrics_stream]
      enrich_with_resource_attributes = ["*"]
    }]
  }

  destinations = {
    log_analytics = [{
      name                  = "logAnalytics"
      workspace_resource_id = module.log_analytics.resource_id
    }]
    monitoring_accounts = [{
      name                = "azureMonitorWorkspace"
      account_resource_id = one(azurerm_monitor_workspace.prometheus[*].id)
    }]
  }

  data_flows = [
    {
      streams      = concat(local.otlp_log_streams, local.otlp_trace_streams)
      destinations = ["logAnalytics"]
    },
    {
      streams      = [local.otlp.metrics_stream]
      destinations = ["azureMonitorWorkspace"]
    },
  ]
}
