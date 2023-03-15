resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name                                           = var.name
  firewall_policy_id                             = var.firewall_policy_id
  priority                                       = var.priority        
  dynamic "application_rule_collection" {
    for_each = var.application_rule_collection == null ? [] : var.application_rule_collection
    content {
      name = application_rule_collection.value.name
      priority = application_rule_collection.value.priority
      action = application_rule_collection.value.action
      dynamic "rule" {
        for_each = application_rule_collection.value.rules == null ? [] : application_rule_collection.value.rules
        content {
          name = rule.value.name
          source_addresses = try(rule.value.source_addresses, null)
          source_ip_groups = try(rule.value.source_ip_groups, null)
          destination_fqdns = try(rule.value.destination_fqdns, null)
          destination_fqdn_tags = try(rule.value.destination_fqdn_tags, null)
          dynamic "protocols" {
            for_each = rule.value.protocols
            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }
  dynamic "network_rule_collection" {
    for_each = var.network_rule_collection == null ? [] : var.network_rule_collection
    content {
      name = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action = network_rule_collection.value.action
      dynamic "rule" {
        for_each = network_rule_collection.value.rules == null ? [] : network_rule_collection.value.rules
        content {
          name = rule.value.name
          protocols = rule.value.protocols
          source_addresses = try(rule.value.source_addresses, null)
          source_ip_groups = try(rule.value.source_ip_groups, null)
          destination_addresses = try(rule.value.destination_addresses, null)
          destination_ip_groups = try(rule.value.destination_ip_groups, null)
          destination_fqdns = try(rule.value.destination_fqdns, null)
          destination_ports = rule.value.destination_ports
        }
      }
    }
  }
  dynamic "nat_rule_collection" {
    for_each = var.nat_rule_collection == null ? [] : var.nat_rule_collection
    content {
      name = nat_rule_collection.value.name
      priority = nat_rule_collection.value.priority
      action = nat_rule_collection.value.action
      dynamic "rule" {
        for_each = nat_rule_collection.value.rules == null ? [] : nat_rule_collection.value.rules
        content {
          name = rule.value.name
          protocols = rule.value.protocols
          translated_address = rule.value.translated_address
          translated_port = rule.value.translated_port
          source_addresses = try(rule.value.source_addresses, null)
          source_ip_groups = try(rule.value.source_ip_groups, null)
          destination_address = try(rule.value.destination_address, null)
          destination_ports = try(rule.value.destination_ports, null)
        }
      }
    }
  }
}
