output "rulecollectiongroup_id" {
  description = "The id of the newly created Rule Collection Group"
  value       = azurerm_firewall_policy_rule_collection_group.this.id
}
