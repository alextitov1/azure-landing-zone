# create a user in EntraID

resource "random_password" "this" {
  length  = var.entraid_user.password.length
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
  department          = var.entraid_user.organization.department
  job_title           = var.entraid_user.organization.job_title
  account_enabled     = var.entraid_user.account_enabled
  usage_location      = var.entraid_user.organization.usage_location

  password = random_password.this.result
  # A password kept in 1Password is the account's credential; any other is a one-time password for the first sign-in
  force_password_change = var.entraid_user.password.onepassword_vault == null
}

resource "onepassword_item" "this" {
  count = var.entraid_user.password.onepassword_vault != null ? 1 : 0
  vault = data.onepassword_vault.this[0].uuid

  title    = "${var.entraid_user.user_principal_name} "
  category = "login"

  username   = var.entraid_user.user_principal_name
  url        = "https://portal.azure.com/${data.azuread_client_config.current.tenant_id}"
  password   = random_password.this.result
  note_value = "managed by terraform"
}