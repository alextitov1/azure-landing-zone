

module "resourcegroup_firewall" {
  source   = "../../modules/resourcegroup"
  name     = "${var.prefix}-rg-${var.ENVIRONMENT}-tfnetwork-001"
  location = var.LOCATION
  tags     = local.all_tags
}


module "azurefirewallbasepolicy" {
  source = "../../modules/network/azurefirewallpolicy"
  depends_on = [
    module.resourcegroup_firewall
  ]
  name                = "${var.prefix}-fp-${var.ENVIRONMENT}-fwpolicy-001"
  resource_group_name = module.resourcegroup_firewall.resourcegroup_name
  location            = var.LOCATION
  sku                 = "Standard"
}