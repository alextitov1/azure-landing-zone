variable "tenant_yaml_path" {
  type        = string
  description = "Path to the tenant YAML file (relative to bootstrap/Azure/terraform)."
  # default     = "../tenants/admin.4esnok.su-vs.yaml"
}

variable "onepassword_service_account_token" {
  type        = string
  description = "1Password service account token used to generate/store user passwords. Set via TF_VAR_onepassword_service_account_token."
  sensitive   = true
}

# Set by HCP Terraform when the workspace uses dynamic Azure credentials (TFC_AZURE_PROVIDER_AUTH);
# null for local runs. Used by providers without built-in HCP support (msgraph).
variable "tfc_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
  description = "Azure dynamic credentials injected by HCP Terraform"
  default     = null
}
