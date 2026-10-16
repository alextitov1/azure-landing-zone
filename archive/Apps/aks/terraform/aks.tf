# module "aks" {
#   source           = "Azure/avm-ptn-aks-production/azurerm"
#   version          = "0.5.0"
#   enable_telemetry = false

#   os_sku = "AzureLinux"


#   location = local.location
#   name     = module.naming.kubernetes_cluster.name_unique
#   network = {
#     node_subnet_id = module.virtual_network.subnets["subnet"].resource_id
#     pod_cidr       = "192.168.0.0/16"
#     service_cidr   = "10.2.0.0/16"
#   }
#   resource_group_name = module.resource_group.name

#   kubernetes_version = "1.32"
# #   network_policy     = "None"
#   #   private_dns_zone_id         = azurerm_private_dns_zone.mydomain.id
#   #   private_dns_zone_id_enabled = true
#   rbac_aad_tenant_id = data.azurerm_client_config.current.tenant_id

# #   node_pools = {
# #     workload = {
# #       name                 = "workload"
# #       vm_size              = "Standard_D2d_v5"
# #       orchestrator_version = "1.30"
# #       max_count            = 110
# #       min_count            = 2
# #       os_sku               = "AzureLinux"
# #       mode                 = "User"
# #     },
# #     ingress = {
# #       name                 = "ingress"
# #       vm_size              = "Standard_D2d_v5"
# #       orchestrator_version = "1.30"
# #       max_count            = 4
# #       min_count            = 2
# #       os_sku               = "AzureLinux"
# #       mode                 = "User"
# #       labels = {
# #         "ingress" = "true"
# #       }
# #     }
# #   }
# }

