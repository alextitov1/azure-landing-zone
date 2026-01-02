# create a user in EntraID

resource "random_password" "this" {
  length  = 15
  special = true
  # Ensure password meets Azure AD complexity requirements
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

resource "azuread_user" "this" {
  user_principal_name = var.entraid_user.user_principal_name
  display_name        = var.entraid_user.display_name
  mail_nickname       = var.entraid_user.mail_nickname
  department          = var.entraid_user.department
  job_title           = var.entraid_user.job_title

  password              = random_password.this.result
  force_password_change = var.entraid_user.store_password_in_key_vault == true ? false : true
}

resource "onepassword_item" "this" {
  count = var.entraid_user.store_password_in_key_vault == true ? 1 : 0
  vault = data.onepassword_vault.this[0].uuid

  title    = "${var.entraid_user.user_principal_name} "
  category = "login"

  username   = var.entraid_user.user_principal_name
  url        = "https://portal.azure.com/${data.azuread_client_config.current.tenant_id}"
  password   = random_password.this.result
  note_value = "managed by terraform"
}