variable "access_package" {
  type = object({
    display_name  = string
    description   = optional(string)
    catalog       = string                     # catalog display name
    groups        = optional(list(string), []) # groups whose membership the package grants
    requestors    = optional(string, "AllExistingDirectoryMemberUsers")
    approvers     = optional(list(string), []) # user mail_nicknames; empty means no approval
    duration_days = optional(number, 90)
    review = optional(object({
      frequency = optional(string, "quarterly") # weekly, monthly, quarterly, halfyearly, annual
      reviewers = list(string)                  # user mail_nicknames
    }))
  })
  description = "Entitlement management access package (requires Entra ID P2 or ID Governance)"
}

variable "catalog_id" {
  type        = string
  description = "ID of the access package catalog"
}

variable "catalog_resource_association_ids" {
  type        = map(string)
  description = "Map of group display names to their catalog resource association IDs"
}

variable "user_ids" {
  type        = map(string)
  description = "Map of user mail_nicknames to their object IDs"
  default     = {}
}
