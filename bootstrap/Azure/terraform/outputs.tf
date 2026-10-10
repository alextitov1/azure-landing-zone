output "hcp_workload_identities" {
  value = {
    for workspace, identity in module.hcp_workload_identity : workspace => {
      client_ids                   = identity.client_ids
      service_principal_object_ids = identity.service_principal_object_ids
    }
  }
  description = "Plan and apply identities per HCP Terraform workspace"
}
