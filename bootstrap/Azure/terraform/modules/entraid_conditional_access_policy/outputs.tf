output "policy_id" {
  value       = azuread_conditional_access_policy.this.id
  description = "The ID of the Conditional Access policy"
}
