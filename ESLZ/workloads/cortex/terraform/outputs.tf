output "resource_group_id" {
  description = "ID of the cortex resource group."
  value       = local.resource_group_id
}

output "subnet_id" {
  description = "ID of the cortex subnet, from the connectivity workspace."
  value       = local.subnet_id
}

output "aks" {
  description = "AKS cluster: ID, name, API server FQDN, OIDC issuer URL (for workload identity federated credentials), node resource group and kubelet identity."
  value = {
    id                  = module.aks.resource_id
    name                = module.aks.name
    fqdn                = module.aks.fqdn
    oidc_issuer_url     = module.aks.oidc_issuer_profile_issuer_url
    node_resource_group = module.aks.node_resource_group_name
    kubelet_identity    = module.aks.kubelet_identity
  }
}

output "registry" {
  description = "Container registry: ID and login server."
  value = {
    id           = module.registry.resource_id
    login_server = module.registry.login_server
  }
}
