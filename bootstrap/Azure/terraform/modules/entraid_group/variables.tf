variable "entraid_group" {
  type = object({
    display_name       = string
    mail_nickname      = optional(string)
    assignable_to_role = optional(bool, false)
    members            = optional(list(string), [])
  })
  description = "Entra ID group configuration"
}

variable "member_ids" {
  type        = map(string)
  description = "Map of member names (user principal names and application display names) to their object IDs"
  default     = {}
}
