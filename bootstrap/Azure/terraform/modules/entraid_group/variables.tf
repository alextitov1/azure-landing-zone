variable "entraid_group" {
  type = object({
    display_name       = string
    mail_nickname      = optional(string)
    assignable_to_role = optional(bool, false)
    members            = optional(list(string), [])
  })
  description = "Entra ID group configuration"
}

variable "user_ids" {
  type        = map(string)
  description = "Map of user principal names to their object IDs"
  default     = {}
}
