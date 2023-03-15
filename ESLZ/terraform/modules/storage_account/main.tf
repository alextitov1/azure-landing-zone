# https://github.com/claranet/terraform-azurerm-storage-account/

resource "azurerm_storage_account" "this" {
  name                      = var.storage_account_name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_kind              = var.account_kind
  account_tier              = split("_", var.skuname)[0]
  account_replication_type  = split("_", var.skuname)[1]
  enable_https_traffic_only = true
  min_tls_version           = var.min_tls_version
  tags                      = var.tags
  public_network_access_enabled = var.public_network_access_enabled
  shared_access_key_enabled = var.shared_access_key_enabled
  cross_tenant_replication_enabled = var.cross_tenant_replication_enabled
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  # network_rules {
  #   default_action = "Deny"
  # }
}

resource "azurerm_storage_container" "container" {
#  for_each = try({ for c in var.containers : c.name => c }, {})
  for_each = toset(var.containers)

  storage_account_name = azurerm_storage_account.this.name
  name                 = each.key
  # container_access_type = each.value.container_access_type
  # metadata              = each.value.metadata
}

#   dynamic "identity" {
#     for_each = var.managed_identity_type != null ? [1] : []
#     content {
#       type         = var.managed_identity_type
#       identity_ids = var.managed_identity_type == "UserAssigned" || var.managed_identity_type == "SystemAssigned, UserAssigned" ? var.managed_identity_ids : null
#     }
#   }

#   blob_properties {
#     delete_retention_policy {
#       days = var.blob_soft_delete_retention_days
#     }
#     container_delete_retention_policy {
#       days = var.container_soft_delete_retention_days
#     }
#     versioning_enabled       = var.enable_versioning
#     last_access_time_enabled = var.last_access_time_enabled
#     change_feed_enabled      = var.change_feed_enabled
#   }




# #-------------------------------
# # Storage Container Creation
# #-------------------------------
# resource "azurerm_storage_container" "container" {
#   count                 = length(var.containers_list)
#   name                  = var.containers_list[count.index].name
#   storage_account_name  = azurerm_storage_account.storeacc.name
#   container_access_type = var.containers_list[count.index].access_type
# }

