output "client_ids" {
  value       = { for phase, app in azuread_application.this : phase => app.client_id }
  description = "Client IDs of the plan and apply identities"
}

output "service_principal_object_ids" {
  value       = { for phase, sp in azuread_service_principal.this : phase => sp.object_id }
  description = "Object IDs of the plan and apply service principals, for Azure RBAC role assignments"
}

output "subjects" {
  value       = { for phase, cred in azuread_application_federated_identity_credential.this : phase => cred.subject }
  description = "OIDC subjects the federated credentials trust"
}
