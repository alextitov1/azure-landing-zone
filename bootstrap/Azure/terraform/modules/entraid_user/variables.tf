variable "entraid_user" {
  type = object({
    user_principal_name         = string
    display_name                = string
    department                  = string
    job_title                   = string
    mail_nickname               = string
    account_enabled             = optional(bool, true)
    usage_location              = optional(string) # two-letter country code, required for licence assignment
    password_length             = optional(number, 15)
    store_password_in_key_vault = optional(bool)
    key_vault_name              = optional(string)
  })
}
