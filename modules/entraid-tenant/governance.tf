# Identity governance and delegation: access packages (P2), administrative units and B2B guests

locals {
  access_package_catalogs_by_name = {
    for catalog in try(var.config.access_package_catalogs, []) : catalog.display_name => catalog
  }

  access_packages_by_name = {
    for package in try(var.config.access_packages, []) : package.display_name => package
  }

  # One catalog resource association per catalog and group, shared by the packages in that catalog
  access_package_catalog_groups = {
    for pair in distinct(flatten([
      for package in try(var.config.access_packages, []) : [
        for group in try(package.groups, []) : { catalog = package.catalog, group = group }
      ]
    ])) : "${pair.catalog}/${pair.group}" => pair
  }

  administrative_units_by_name = {
    for unit in try(var.config.administrative_units, []) : unit.display_name => unit
  }

  administrative_unit_members = {
    for pair in flatten([
      for unit in try(var.config.administrative_units, []) : [
        for member in try(unit.members, []) : { unit = unit.display_name, member = member }
      ]
    ]) : "${pair.unit}/${pair.member}" => pair
  }

  administrative_unit_role_assignments = {
    for assignment in flatten([
      for unit in try(var.config.administrative_units, []) : [
        for role in try(unit.role_assignments, []) : { unit = unit.display_name, role_name = role.role_name, assignee = role.assignee }
      ]
    ]) : "${assignment.unit}/${assignment.role_name}/${assignment.assignee}" => assignment
  }

  guests_by_email = {
    for guest in try(var.config.guests, []) : guest.email => guest
  }

  # Users (by mail_nickname) and groups (by display name), for administrative unit membership
  directory_object_ids = merge(
    local.user_ids,
    { for k, v in module.entraid_group : k => v.group_id },
  )
}

# Access packages (require Entra ID P2 or ID Governance)
resource "azuread_access_package_catalog" "this" {
  for_each     = local.access_package_catalogs_by_name
  display_name = each.key
  description  = coalesce(try(each.value.description, null), each.key)
}

resource "azuread_access_package_resource_catalog_association" "this" {
  for_each = local.access_package_catalog_groups

  catalog_id             = azuread_access_package_catalog.this[each.value.catalog].id
  resource_origin_id     = module.entraid_group[each.value.group].group_id
  resource_origin_system = "AadGroup"
}

module "entraid_access_package" {
  source   = "../entraid-access-package"
  for_each = local.access_packages_by_name

  access_package = each.value
  catalog_id     = azuread_access_package_catalog.this[each.value.catalog].id
  catalog_resource_association_ids = {
    for key, association in azuread_access_package_resource_catalog_association.this :
    local.access_package_catalog_groups[key].group => association.id
    if local.access_package_catalog_groups[key].catalog == each.value.catalog
  }
  user_ids = local.user_ids
}

# Administrative units: scope admin roles to a subset of users and groups
# (administrators of an administrative unit need Entra ID P1)
resource "azuread_administrative_unit" "this" {
  for_each     = local.administrative_units_by_name
  display_name = each.key
  description  = try(each.value.description, null)
}

resource "azuread_administrative_unit_member" "this" {
  for_each = local.administrative_unit_members

  administrative_unit_object_id = azuread_administrative_unit.this[each.value.unit].object_id
  member_object_id              = local.directory_object_ids[each.value.member]
}

resource "azuread_administrative_unit_role_member" "this" {
  for_each = local.administrative_unit_role_assignments

  administrative_unit_object_id = azuread_administrative_unit.this[each.value.unit].object_id
  role_object_id                = azuread_directory_role.activated[each.value.role_name].object_id
  member_object_id              = local.directory_object_ids[each.value.assignee]
}

# B2B guests
resource "azuread_invitation" "this" {
  for_each = local.guests_by_email

  user_email_address = each.key
  user_display_name  = try(each.value.display_name, null)
  redirect_url       = try(each.value.redirect_url, "https://myapps.microsoft.com")
}
