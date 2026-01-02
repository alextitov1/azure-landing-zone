resource "azuread_group" "this" {
  display_name       = var.entraid_group.display_name
  mail_nickname      = try(var.entraid_group.mail_nickname, var.entraid_group.display_name)
  assignable_to_role = var.entraid_group.assignable_to_role
  security_enabled   = try(var.entraid_group.security_enabled, true)

  members = [
    for upn in var.entraid_group.members : var.user_ids[upn]
  ]
}