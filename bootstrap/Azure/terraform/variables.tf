variable "tenant_yaml_path" {
  type        = string
  description = "Path to the tenant YAML file (relative to ESLZ/bootstrap/terraform)."
  # default     = "../tenants/admin.4esnok.su-vs.yaml"
}

variable "onepassword_service_account_token" {
  type        = string
  description = "1Password service account token used to generate/store user passwords. Set via TF_VAR_onepassword_service_account_token."
  sensitive   = true
}
