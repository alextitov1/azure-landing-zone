variable "entraid_application" {
  type = object({
    display_name    = string
    description     = optional(string)
    owners          = optional(list(string), []) # user mail_nicknames
    graph_app_roles = optional(list(string), []) # Microsoft Graph application permissions, e.g. Directory.Read.All
    # Workload identity federation, e.g. HCP Terraform dynamic credentials; the defaults are HCP Terraform's
    federated_credentials = optional(list(object({
      name        = string
      subject     = string # e.g. organization:<org>:project:<project>:workspace:<workspace>:run_phase:<plan|apply>
      issuer      = optional(string, "https://app.terraform.io")
      audiences   = optional(list(string), ["api://AzureADTokenExchange"])
      description = optional(string)
    })), [])
    client_secret = optional(object({
      key_vault_name = string                # 1Password vault that stores the secret
      rotation_days  = optional(number, 180) # a new secret is created on the first apply after this many days
      overlap_days   = optional(number, 30)  # the secret stays valid this long after its rotation date
    }))
  })
  description = "Entra ID application (app registration and enterprise application) configuration"
}

variable "user_ids" {
  type        = map(string)
  description = "Map of user mail_nicknames to their object IDs"
  default     = {}
}
