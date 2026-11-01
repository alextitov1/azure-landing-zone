variable "entraid_user" {
  type = object({
    user_principal_name = string
    display_name        = string
    mail_nickname       = string
    account_enabled     = optional(bool, true)
    organization = optional(object({
      department     = optional(string)
      job_title      = optional(string)
      usage_location = optional(string) # two-letter country code, required for licence assignment
    }), {})
    password = optional(object({
      length            = optional(number, 15)
      onepassword_vault = optional(string)
    }), {})
  })
}
