variable "pim_role" {
  type = object({
    role_name       = string
    assignment_type = string           # "Group", "User" or "ServicePrincipal"
    assignee_name   = string           # group display_name, user_principal_name or application display_name
    duration        = optional(string) # maximum activation duration (ISO 8601, e.g. PT4H); applied per role at root level
  })
  description = "PIM role eligibility configuration"
}

variable "role_template_id" {
  type        = string
  description = "The template ID of the directory role"
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

variable "service_principal_ids" {
  type        = map(string)
  description = "Map of application display names to their service principal object IDs"
  default     = {}
}
