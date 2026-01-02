variable "pim_role" {
  type = object({
    role_name       = string
    assignment_type = string # "Group" or "User"
    assignee_name   = string # group display_name or user_principal_name
    duration        = string # ISO 8601 duration, e.g., "PT4H"
  })
  description = "PIM role eligibility configuration"
}

variable "group_ids" {
  type        = map(string)
  description = "Map of group display names to their object IDs"
  default     = {}
}

variable "user_ids" {
  type        = map(string)
  description = "Map of user principal names to their object IDs"
  default     = {}
}
