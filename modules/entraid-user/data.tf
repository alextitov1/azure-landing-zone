data "onepassword_vault" "this" {
  count = var.entraid_user.password.onepassword_vault != null ? 1 : 0

  name = var.entraid_user.password.onepassword_vault
}

data "azuread_client_config" "current" {}