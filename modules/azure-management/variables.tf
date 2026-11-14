variable "config" {
  type        = any
  description = "The decoded ESLZ/management/config/management.yaml; see ESLZ/management/README.md."

  validation {
    condition     = !try(var.config.grafana.enabled, false) || try(var.config.grafana.identity, null) != null
    error_message = "grafana.identity is required: the user-assigned identity that subscription vending creates for Grafana."
  }

  validation {
    condition     = !try(var.config.otlp.enabled, false) || try(var.config.prometheus.enabled, false)
    error_message = "otlp is enabled, so prometheus.enabled is required: OTLP metrics go to the Azure Monitor workspace."
  }
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet of the private link scope's private endpoint (the connectivity `subnets` output); required when private_link is enabled."
  default     = null

  validation {
    condition     = !try(var.config.private_link.enabled, false) || var.private_endpoint_subnet_id != null
    error_message = "private_link is enabled, so private_endpoint_subnet_id is required."
  }
}

variable "grafana_smtp_password" {
  type        = string
  description = "Password of the SMTP server Azure Managed Grafana sends email through; only when grafana.smtp is set."
  default     = null
  sensitive   = true
}
