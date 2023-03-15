

module "azurefirewallpolicyrulecollectiongroup" {
    source = "../modules/network/azurefirewallpolicyrulecollectiongroup"
    name                            = "tf_policy_collection01"
    priority                        = 103
    firewall_policy_id              = data.terraform_remote_state.firewall.outputs.azurefirewallbasepolicy_id
}