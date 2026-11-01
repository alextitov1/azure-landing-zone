variable "policy" {
  type = object({
    display_name = string
    state        = optional(string, "enabledForReportingButNotEnforced") # enabled, disabled or enabledForReportingButNotEnforced (report-only)
    users = object({
      include        = optional(list(string), []) # user mail_nicknames, or All, None, GuestsOrExternalUsers
      exclude        = optional(list(string), [])
      include_groups = optional(list(string), []) # group display names
      exclude_groups = optional(list(string), [])
      include_roles  = optional(list(string), []) # directory role names, e.g. Global Administrator
      exclude_roles  = optional(list(string), [])
    })
    applications = optional(object({
      include = optional(list(string), ["All"]) # application IDs, or All, None, Office365, MicrosoftAdminPortals
      exclude = optional(list(string), [])
    }), {})
    client_app_types = optional(list(string), ["all"]) # all, browser, mobileAppsAndDesktopClients, exchangeActiveSync, other
    locations = optional(object({
      include = optional(list(string), []) # named location display names, or All, AllTrusted
      exclude = optional(list(string), [])
    }))
    grant = object({
      operator                = optional(string, "OR")
      controls                = optional(list(string), []) # block, mfa, compliantDevice, domainJoinedDevice, passwordChange, ...
      authentication_strength = optional(string)           # built-in or custom authentication strength display name
    })
  })
  description = "Conditional Access policy configuration; names are resolved to object IDs"
}

variable "user_ids" {
  type        = map(string)
  description = "Map of user mail_nicknames to their object IDs"
  default     = {}
}

variable "group_ids" {
  type        = map(string)
  description = "Map of group display names to their object IDs"
  default     = {}
}

variable "role_template_ids" {
  type        = map(string)
  description = "Map of directory role display names to their template IDs"
  default     = {}
}

variable "named_location_ids" {
  type        = map(string)
  description = "Map of named location display names to their IDs"
  default     = {}
}

variable "authentication_strength_ids" {
  type        = map(string)
  description = "Map of authentication strength display names to their policy IDs"
  default     = {}
}
