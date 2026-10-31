variable "organization_name" {
  description = "Name of the HCP Terraform organization."
  type        = string
}

variable "project_name" {
  description = "Name of the project to create."
  type        = string
}

variable "project_description" {
  description = "Description of the project."
  type        = string
  default     = null
}

variable "secret_env_vars" {
  description = "Sensitive environment variables per workspace: { <workspace> = { <key> = <secret reference> } }; each reference is a key of secret_values."
  type        = map(map(string))
  default     = {}
}

variable "secret_values" {
  description = "Secret values by reference, e.g. from an ephemeral resource. Only written to write-only attributes, never to state."
  type        = map(string)
  ephemeral   = true
  default     = {}
}

variable "workspaces" {
  description = "Map of workspaces to create within the project. Key is the workspace name."
  type = map(object({
    description       = optional(string)
    terraform_version = optional(string)      # version or constraint, e.g. "~> 1.16"
    auto_apply        = optional(bool, false) # API, UI and VCS runs, and runs started by run triggers
    working_directory = optional(string)
    trigger_patterns  = optional(list(string))
    tags              = optional(map(string), {})
    env_vars          = optional(map(string), {}) # environment variables
    auto_destroy = optional(object({              # schedule a destroy run; set exactly one field
      at               = optional(string)         # RFC3339 time, e.g. "2026-10-31T18:00:00Z"
      after_inactivity = optional(string)         # e.g. "3d" or "12h" after the last run
    }))
    vcs_repo = optional(object({
      identifier                 = string
      branch                     = optional(string)
      oauth_token_id             = optional(string) # OAuth VCS connection (works with team tokens)
      github_app_installation_id = optional(string) # GitHub App (requires a user token)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for ws in values(var.workspaces) :
      ws.vcs_repo == null ? true : (ws.vcs_repo.oauth_token_id == null) != (ws.vcs_repo.github_app_installation_id == null)
    ])
    error_message = "vcs_repo needs exactly one of oauth_token_id or github_app_installation_id."
  }

  validation {
    condition = alltrue([
      for ws in values(var.workspaces) :
      ws.auto_destroy == null ? true : (
        (ws.auto_destroy.at == null) != (ws.auto_destroy.after_inactivity == null) &&
        (ws.auto_destroy.at == null || can(formatdate("YYYY", ws.auto_destroy.at))) &&
        (ws.auto_destroy.after_inactivity == null || can(regex("^[1-9][0-9]*[dh]$", ws.auto_destroy.after_inactivity)))
      )
    ])
    error_message = "auto_destroy needs exactly one of at (RFC3339 time) or after_inactivity (<number>d or <number>h)."
  }
}
