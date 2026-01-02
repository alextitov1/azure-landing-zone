data "onepassword_vault" "this" {
  count = var.entraid_user.store_password_in_key_vault == true ? 1 : 0

  name = var.entraid_user.key_vault_name
}

data "azuread_client_config" "current" {}