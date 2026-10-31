variable "references" {
  description = "1Password references to read: op://<vault>/<item>/<field>, where field is a built-in one (credential, password, ...) or <section>/<field>."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for ref in var.references : can(regex("^op://([^/]+)/([^/]+)/(.+)$", ref))])
    error_message = "Each reference must look like op://<vault>/<item>/<field>."
  }
}
