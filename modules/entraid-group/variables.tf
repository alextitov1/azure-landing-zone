variable "entraid_group" {
  type = object({
    display_name       = string
    description        = optional(string)
    mail_nickname      = optional(string)
    assignable_to_role = optional(bool, false)
    security_enabled   = optional(bool, true)
    members            = optional(list(string), [])
    dynamic_rule       = optional(string) # dynamic membership rule (Entra ID P1); members must then be empty
    licenses = optional(list(object({     # group-based licensing (Entra ID P1)
      sku            = string             # SKU part number, e.g. SPB (Microsoft 365 Business Premium)
      disabled_plans = optional(list(string), [])
    })), [])
  })
  description = "Entra ID group configuration"
}

variable "member_ids" {
  type        = map(string)
  description = "Map of member names (user mail_nicknames and application display names) to their object IDs"
  default     = {}
}

variable "sku_ids" {
  type        = map(string)
  description = "Map of SKU part numbers to SKU IDs of the tenant's subscribed SKUs"
  default     = {}
}

variable "service_plan_ids" {
  type        = map(map(string))
  description = "Map of SKU part numbers to a map of service plan names to service plan IDs"
  default     = {}
}
