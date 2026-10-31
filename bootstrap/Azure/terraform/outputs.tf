output "applications" {
  value = {
    for name, app in module.entraid_application : name => {
      client_id                   = app.client_id
      service_principal_object_id = app.service_principal_object_id
    }
  }
  description = "Client IDs and service principal object IDs of the Entra ID applications"
}

output "domain_verification_records" {
  value       = { for name, records in data.msgraph_resource.domain_verification_records : name => records.output.records }
  description = "DNS records that prove ownership of each custom domain from the YAML"
}

output "break_glass_users" {
  value       = local.break_glass_upns
  description = "Emergency access accounts, excluded from Conditional Access"
}

output "tenant_id" {
  value       = data.azuread_client_config.current.tenant_id
  description = "Entra ID tenant ID"
}

output "management_group_ids" {
  value       = try(module.management_groups[0].management_group_resource_ids, {})
  description = "Resource IDs of the management groups from the YAML"
}
