# Platform management, from ../config/management.yaml (README.md): the central Log Analytics workspace, managed
# Prometheus, Managed Grafana, OTLP ingestion and the Azure Monitor private link scope (ESLZ/management_design.md).

locals {
  config       = yamldecode(file("${path.module}/../config/management.yaml"))
  private_link = try(local.config.private_link, { enabled = false })
}

# Outputs of ESLZ/connectivity, for the private link scope's endpoint in the hub
data "tfe_outputs" "connectivity" {
  count = local.private_link.enabled ? 1 : 0

  organization = "4esnok"
  workspace    = "4esnok_vs_azure_networking_r1"
}

module "management" {
  source = "../../../modules/azure-management"

  config                     = local.config
  private_endpoint_subnet_id = local.private_link.enabled ? data.tfe_outputs.connectivity[0].nonsensitive_values.subnets[local.private_link.subnet] : null
  grafana_smtp_password      = var.grafana_smtp_password
}
