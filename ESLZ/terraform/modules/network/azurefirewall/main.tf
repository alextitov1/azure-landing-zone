

resource "azurerm_firewall" "this" {
  name     = var.name
  location = var.location
  resource_group_name = var.resource_group_name
  sku_name = var.sku_name
  sku_tier = var.sku_tier
  firewall_policy_id = var.firewall_policy_id
  threat_intel_mode = var.threat_intel_mode
  zones = var.zones
  dns_servers = var.dns_servers
  

  dynamic "ip_configuration" {
    for_each = var.ip_configurations == null ? [] : var.ip_configurations
    content {
      name = ip_configuration.value.name
      subnet_id = lookup(ip_configuration.value, "subnet_id", null) == null ? null : ip_configuration.value.subnet_id
      public_ip_address_id = ip_configuration.value.public_ip_address_id
    }
  }  
  
  dynamic "management_ip_configuration" {
    for_each = var.management_ip_configuration == null ? [] : var.management_ip_configuration
    content {
      name = management_ip_configuration.value.name
      public_ip_address_id = management_ip_configuration.value.public_ip_address_id
      subnet_id = management_ip_configuration.value.subnet_id
    }
  }

  dynamic "virtual_hub" {
    for_each = var.virtual_hub == null ? [] : var.virtual_hub
    content {
      virtual_hub_id = virtual_hub.value.virtual_hub_name
      public_ip_count = virtual_hub.value.public_ip_count
    }
  }
  tags = var.tags
}


