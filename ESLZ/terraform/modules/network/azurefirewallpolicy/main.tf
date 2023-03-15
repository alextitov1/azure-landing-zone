
resource "azurerm_firewall_policy" "this" {
  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  sku                                            = var.sku
  base_policy_id                                 = var.base_policy_id
  dynamic "dns" {
    for_each = var.dns == null ? [] : var.dns
    content {
      servers = dns.value.servers
      proxy_enabled = dns.value.proxy_enabled
    }
  }         
  threat_intelligence_mode                       = var.threat_intelligence_mode
  dynamic "threat_intelligence_allowlist" {
    for_each = var.threat_intelligence_allowlist == null ? [] : var.threat_intelligence_allowlist
    content {
      ip_addresses = threat_intelligence_allowlist.value.ip_addresses
      fqdns = threat_intelligence_allowlist.value.fqdns
    }
  }
  dynamic "identity" {
    for_each = var.identity == null ? [] : var.identity
    content{
      type = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
  dynamic "tls_certificate" {
    for_each = var.tls_certificate == null ? [] : var.tls_certificate
    content{
      key_vault_secret_id = tls_certificate.value.key_vault_secret_id
      name =  tls_certificate.value.cert_name
    }
  }
  dynamic "intrusion_detection" {
    for_each = var.intrusion_detection == null ? [] : var.intrusion_detection
    content {
      mode = intrusion_detection.value.mode
      dynamic "signature_overrides" {
        for_each = intrusion_detection.value.signature_overrides == null ? [] : intrusion_detection.value.signature_overrides
        content {
          id = signature_overrides.value.id
          state = signature_overrides.value.state
        }
      }
      dynamic "traffic_bypass" {
        for_each = intrusion_detection.value.traffic_bypass == null ? [] : intrusion_detection.value.traffic_bypass
        content {
          name = traffic_bypass.value.bypass_rule_name
          protocol = traffic_bypass.value.protocol
          description = try(traffic_bypass.value.description, null)
          source_addresses = try(traffic_bypass.value.source_addresses, null)
          source_ip_groups = try(traffic_bypass.value.source_ip_groups, null)
          destination_addresses = try(traffic_bypass.value.destination_addresses, null)
          destination_ip_groups = try(traffic_bypass.value.destination_ip_groups, null)
          destination_ports = try(traffic_bypass.value.destination_ports, null)
        }
      }
    }
  }
  dynamic "insights" {
    for_each = var.insights == null ? [] : var.insights
    content{
      enabled = insights.value.enabled
      default_log_analytics_workspace_id = insights.value.default_log_analytics_workspace_id
      retention_in_days = try(insights.value.retention_in_days, null)
      dynamic "log_analytics_workspace" {
        for_each = insights.value.log_analytics_workspace == null ? [] : insights.value.log_analytics_workspace
        content {
          id = log_analytics_workspace.id
          firewall_location = log_analytics_workspace.firewall_location
        }
      }
    }
  }
  dynamic "explicit_proxy" {
    for_each = var.explicit_proxy == null ? [] : var.explicit_proxy
    content{
      enabled = try(explicit_proxy.value.enabled, null)
      http_port = try(explicit_proxy.value.http_port, null)
      https_port = try(explicit_proxy.value.https_port, null)
      enable_pac_file = try(explicit_proxy.value.enable_pac_file, null)
      pac_file_port = try(explicit_proxy.value.pac_file_port, null)
      pac_file = try(explicit_proxy.value.pac_file, null)
    }
  }
  tags = var.tags
}
