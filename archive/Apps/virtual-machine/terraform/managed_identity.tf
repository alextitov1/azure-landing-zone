resource "azurerm_user_assigned_identity" "vm_managed_identity1" {
  location            = local.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = module.resource_group.name
  #   tags                = local.tags
}
