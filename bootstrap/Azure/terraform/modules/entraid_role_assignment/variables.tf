variable "role_assignment" {
  type = object({
    role_name       = string
    assignment_type = string # "Group" or "User"
    assignee_name   = string # group display_name or user_principal_name
  })
  description = "Entra ID directory role assignment configuration"
}

variable "role_id" {
  type        = string
  description = "The template ID of the activated directory role"
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
