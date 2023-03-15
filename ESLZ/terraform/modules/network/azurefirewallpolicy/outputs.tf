output "firewallpolicy_id" {
  description = "The id of the newly created policy"
  value       = azurerm_firewall_policy.this.id
}

output "firewallpolicy_child_policies" {
  description = "List of child policies of this [parent] policy if any"
  value       = azurerm_firewall_policy.this.child_policies
}

output "firewallpolicy_firewalls" {
  description = "A list of Firewalls this policy is associated with"
  value       = azurerm_firewall_policy.this.firewalls
}

output "firewallpolicy_rule_collection_groups" {
  description = "A list of Rule Collection Groups belonging to this policy"
  value       = azurerm_firewall_policy.this.rule_collection_groups
}
