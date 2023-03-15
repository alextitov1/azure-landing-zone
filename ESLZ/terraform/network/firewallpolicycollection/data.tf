# data "terraform_remote_state" "lauchpad" {
#   backend = "local"

#   config = {
#     path = "../../launchpad/terraform.tfstate"
#   }
# }



data "terraform_remote_state" "firewall" {
  backend = "azurerm"
  config = {
    use_azuread_auth     = true
    storage_account_name = "stsndbxtfstate01"

#    storage_account_name = data.terraform_remote_state.lauchpad.outputs.st_stfiles_name
    container_name       = "firewall"
    key                  = "terraform.tfstate"
    # subscription_id      = ARM_SUBSCRIPTION_ID
    # tenant_id            = ARM_TENANT_ID
  }
}
