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
