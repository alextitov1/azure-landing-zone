output "client_id" {
  value       = azuread_application.this.client_id
  description = "The client (application) ID"
}

output "application_object_id" {
  value       = azuread_application.this.object_id
  description = "The object ID of the app registration"
}

output "service_principal_object_id" {
  value       = azuread_service_principal.this.object_id
  description = "The object ID of the enterprise application (service principal)"
}
