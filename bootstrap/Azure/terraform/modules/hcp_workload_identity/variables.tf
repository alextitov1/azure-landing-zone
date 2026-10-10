variable "organization" {
  type        = string
  description = "HCP Terraform organization that owns the workspace."
}

variable "project" {
  type        = string
  description = "HCP Terraform project that contains the workspace."
}

variable "workspace" {
  type        = string
  description = "HCP Terraform workspace that authenticates to Azure with these identities."
}

variable "hostname" {
  type        = string
  description = "HCP Terraform hostname; it is also the OIDC token issuer."
  default     = "app.terraform.io"
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID, set as ARM_TENANT_ID on the workspace."
}

variable "subscription_id" {
  type        = string
  description = "Optional default subscription, set as ARM_SUBSCRIPTION_ID on the workspace (needed by azurerm)."
  default     = null
}

variable "plan_graph_app_roles" {
  type        = list(string)
  description = "Microsoft Graph application permissions granted to the plan identity, e.g. Directory.Read.All."
  default     = []
}

variable "apply_graph_app_roles" {
  type        = list(string)
  description = "Microsoft Graph application permissions granted to the apply identity, e.g. User.ReadWrite.All."
  default     = []
}

variable "set_workspace_variables" {
  type        = bool
  description = "Write the TFC_AZURE_* and ARM_* environment variables to the workspace. The workspace must already exist."
  default     = true
}
