# Set by HCP Terraform when the workspace uses dynamic Azure credentials (TFC_AZURE_PROVIDER_AUTH);
# null for local runs. Passed to every provider, as azapi and alz have no built-in HCP support.
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
