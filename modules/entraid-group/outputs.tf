output "group_id" {
  value       = azuread_group.this.object_id
  description = "The object ID of the Entra ID group"
}

output "display_name" {
  value       = azuread_group.this.display_name
  description = "The display name of the Entra ID group"
}
