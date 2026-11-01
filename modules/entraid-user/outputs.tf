output "user_id" {
  value       = azuread_user.this.object_id
  description = "The object ID of the Entra ID user"
}

output "user_principal_name" {
  value       = azuread_user.this.user_principal_name
  description = "The user principal name"
}
