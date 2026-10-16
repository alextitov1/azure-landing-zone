resource "azurerm_kubernetes_cluster" "aks2" {
  name                = module.naming.kubernetes_cluster.name_unique
  kubernetes_version  = local.kubernetes_version
  location            = local.location
  resource_group_name = module.resource_group.name
  dns_prefix          = "mydnsprefix"
  sku_tier            = "Free"

  default_node_pool {
    name       = "system"
    os_sku     = "AzureLinux"
    node_count = 1
    vm_size    = "standard_a2_v2"
    host_encryption_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  # azure_active_directory_role_based_access_control {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   admin_group_object_ids = [
  #     local.aks_admin_group
  #   ]
  # }
}
