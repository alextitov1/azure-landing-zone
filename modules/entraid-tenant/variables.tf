variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID (entraid_tenant_id in the tenant config); the plan fails when signed in to another tenant."
}

variable "config" {
  type        = any
  description = "The entra_id section of the tenant config (bootstrap/Azure/<tenant>/config.yaml or entraid/tenants/<tenant>/config.yaml); see entraid/README.md for the schema."
}
