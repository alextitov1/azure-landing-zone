data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

data "azuread_client_config" "current" {}

data "onepassword_vault" "this" {
  count = var.entraid_application.client_secret != null ? 1 : 0

  name = var.entraid_application.client_secret.key_vault_name
}
