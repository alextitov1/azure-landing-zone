

module "resourcegroup_storageaccount" {
  source = "../modules/resourcegroup"
  name = "${var.prefix}-rg-${var.environment}-tfstatefile-001"
  location = var.location
  tags = local.all_tags
}


module "storageaccount_stfiles" {
  source = "../modules/storage_account"
  storage_account_name = "${var.prefix}st${var.environment}tfstate01"
  resource_group_name = module.resourcegroup_storageaccount.resourcegroup_name
  public_network_access_enabled = true
  shared_access_key_enabled = false
  location = var.location

  containers = ["firewall", "firewallpolicycollection", "nsg"]

  depends_on = [
    module.resourcegroup_storageaccount
  ]
}
