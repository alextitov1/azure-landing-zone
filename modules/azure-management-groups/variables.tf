variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID (entraid_tenant_id in the config), whose tenant root group is the parent of the hierarchy; the plan fails when signed in to another tenant."
}

variable "config" {
  type        = any
  description = "The management_groups section of ESLZ/governance/config.yaml; see ESLZ/governance/README.md for the schema."
}
