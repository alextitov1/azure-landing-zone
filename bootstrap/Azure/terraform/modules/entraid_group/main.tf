resource "azuread_group" "this" {
  display_name       = var.entraid_group.display_name
  mail_nickname      = try(var.entraid_group.mail_nickname, var.entraid_group.display_name)
  assignable_to_role = var.entraid_group.assignable_to_role
  security_enabled   = var.entraid_group.security_enabled

  # Dynamic membership (Entra ID P1): members are calculated from the rule
  types = var.entraid_group.dynamic_rule != null ? ["DynamicMembership"] : null

  dynamic "dynamic_membership" {
    for_each = var.entraid_group.dynamic_rule != null ? [var.entraid_group.dynamic_rule] : []
    content {
      enabled = true
      rule    = dynamic_membership.value
    }
  }

  members = var.entraid_group.dynamic_rule != null ? null : [
    for member in var.entraid_group.members : var.member_ids[member]
  ]
}

# Group-based licensing (Entra ID P1). Members also need a usage_location.
locals {
  licenses_by_sku = { for license in var.entraid_group.licenses : license.sku => license }
}

resource "msgraph_resource_action" "assign_license" {
  for_each = local.licenses_by_sku

  resource_url = "groups/${azuread_group.this.object_id}"
  action       = "assignLicense"
  method       = "POST"
  body = {
    addLicenses = [{
      skuId         = var.sku_ids[each.key]
      disabledPlans = [for plan in each.value.disabled_plans : var.service_plan_ids[each.key][plan]]
    }]
    removeLicenses = []
  }
}

# Removes the licence when it is taken out of the YAML
resource "msgraph_resource_action" "unassign_license" {
  for_each = local.licenses_by_sku

  resource_url = "groups/${azuread_group.this.object_id}"
  action       = "assignLicense"
  method       = "POST"
  when         = "destroy"
  body = {
    addLicenses    = []
    removeLicenses = [var.sku_ids[each.key]]
  }
}
