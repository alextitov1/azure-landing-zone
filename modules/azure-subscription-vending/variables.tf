variable "landing_zones" {
  type        = any
  description = "Landing zones by name: the decoded files of ESLZ/governance/subscriptions; see ESLZ/governance/README.md for the schema."

  validation {
    condition = alltrue([
      for lz in values(var.landing_zones) :
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lz.subscription_id)) && try(lz.location != "", false)
    ])
    error_message = "Each landing zone needs subscription_id, a lowercase GUID, and location."
  }

  validation {
    condition = alltrue([
      for sub in distinct([for lz in values(var.landing_zones) : try(lz.subscription_id, "")]) : length([
        for lz in values(var.landing_zones) : lz
        if try(lz.subscription_id, "") == sub && (
          anytrue([for k in ["display_name", "tags", "management_group_id", "role_assignments"] : try(length(lz[k]) > 0, false)]) ||
          anytrue([for b in try(values(lz.budgets), []) : try(b.resource_group, null) == null])
        )
      ]) <= 1
    ])
    error_message = "Only one landing zone per subscription_id may set display_name, tags, management_group_id, role_assignments or a budget without resource_group."
  }

  validation {
    condition = alltrue([
      for lz in values(var.landing_zones) : contains(keys(var.management_group_ids), lz.management_group_id)
      if try(lz.management_group_id, null) != null
    ])
    error_message = "management_group_id must be a management group of the hierarchy (the architecture in ESLZ/governance/alz-lib)."
  }
}

variable "management_group_ids" {
  type        = map(string)
  description = "Resource IDs of the management groups, by name (output of modules/azure-management-groups)."
}
