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

# Read by bootstrap/HCP/tier1 (azure_oidc.from_workspace) to set TFC_AZURE_* on each workspace.
# Derived from federated credential subjects: ...:workspace:<name>:run_phase:<plan|apply>
locals {
  hcp_oidc_credentials = flatten([
    for app in try(local.tenant_config.applications, []) : [
      for cred in try(app.federated_credentials, []) : {
        workspace = regex(":workspace:([^:]+):run_phase:(plan|apply)$", cred.subject)[0]
        phase     = regex(":workspace:([^:]+):run_phase:(plan|apply)$", cred.subject)[1]
        client_id = module.entraid_application[app.display_name].client_id
      } if cred.issuer == "https://app.terraform.io" && can(regex(":workspace:([^:]+):run_phase:(plan|apply)$", cred.subject))
    ]
  ])
}

output "hcp_oidc" {
  value = {
    tenant_id = data.azuread_client_config.current.tenant_id
    workspaces = {
      for ws in distinct([for c in local.hcp_oidc_credentials : c.workspace]) : ws => {
        for c in local.hcp_oidc_credentials : c.phase => c.client_id if c.workspace == ws
      }
    }
  }
  description = "Tenant ID and HCP Terraform OIDC client IDs (plan, apply) per workspace"
}
