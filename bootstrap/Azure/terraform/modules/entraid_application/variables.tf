variable "entraid_application" {
  type = object({
    display_name = string
    description  = optional(string)
    owners       = optional(list(string), []) # user principal names
    federated_credentials = optional(list(object({
      name        = string
      issuer      = string
      subject     = string
      audiences   = optional(list(string), ["api://AzureADTokenExchange"])
      description = optional(string)
    })), [])
    graph_app_roles = optional(list(string), []) # Microsoft Graph application permissions, e.g. Directory.Read.All
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
  description = "Map of user principal names to their object IDs"
  default     = {}
}
