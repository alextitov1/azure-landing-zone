output "tenant_id" {
  value       = data.azuread_client_config.current.tenant_id
  description = "Entra ID tenant ID"
}

output "applications" {
  value = {
    for name, app in module.entraid_application : name => {
      client_id                   = app.client_id
      service_principal_object_id = app.service_principal_object_id
    }
  }
  description = "Client IDs and service principal object IDs of the Entra ID applications"
}

output "user_ids" {
  value       = local.user_ids
  description = "Object IDs of the users and existing_users, by mail_nickname"
}

output "group_ids" {
  value       = { for name, group in module.entraid_group : name => group.group_id }
  description = "Object IDs of the groups, by display name"
}

output "service_principal_ids" {
  value       = { for name, app in module.entraid_application : name => app.service_principal_object_id }
  description = "Object IDs of the applications' service principals, by display name"
}

output "domain_verification_records" {
  value       = { for name, records in data.msgraph_resource.domain_verification_records : name => records.output.records }
  description = "DNS records that prove ownership of each custom domain from the config"
}
