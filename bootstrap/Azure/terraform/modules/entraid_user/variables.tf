variable "entraid_user" {
  type = object({
    user_principal_name         = string
    display_name                = string
    department                  = string
    job_title                   = string
    mail_nickname               = string
    store_password_in_key_vault = optional(bool)
    key_vault_name              = optional(string)
  })
  default = {
    user_principal_name = "adm_test@4esnok.su"
    display_name        = ""
    department          = ""
    job_title           = ""
    mail_nickname       = ""
  }
}
