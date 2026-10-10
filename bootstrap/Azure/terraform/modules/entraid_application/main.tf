# create an app registration and its enterprise application (service principal) in EntraID

locals {
  owner_ids = [for upn in var.entraid_application.owners : var.user_ids[upn]]
}

resource "azuread_application" "this" {
  display_name = var.entraid_application.display_name
  description  = var.entraid_application.description
  notes        = "managed by terraform"
  owners       = local.owner_ids
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
  owners    = local.owner_ids
}

# Workload identity federation, e.g. HCP Terraform or GitHub Actions OIDC tokens
resource "azuread_application_federated_identity_credential" "this" {
  for_each = { for cred in var.entraid_application.federated_credentials : cred.name => cred }

  application_id = azuread_application.this.id
  display_name   = each.key
  description    = each.value.description
  issuer         = each.value.issuer
  subject        = each.value.subject
  audiences      = each.value.audiences
}

# Microsoft Graph application permissions (admin consent is implied by the assignment)
resource "azuread_app_role_assignment" "graph" {
  for_each = toset(var.entraid_application.graph_app_roles)

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  principal_object_id = azuread_service_principal.this.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
