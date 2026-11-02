variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID, which is also the ID of the tenant root group"
}

variable "config" {
  type        = any
  description = "The management_groups section of a tier-0 tenant config (name, display_name, require_authorization_for_group_creation, role_assignments with role and group); see bootstrap/Azure/README.md#intermediate-root."
}

variable "group_ids" {
  type        = map(string)
  description = "Object IDs of Entra ID groups, by display name"
}
