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
  description = "Sensitive environment variables per workspace: { <workspace> = { <key> = <value> } }."
  type        = map(map(string))
  sensitive   = true
  default     = {}
}

variable "workspaces" {
  description = "Map of workspaces to create within the project. Key is the workspace name."
  type = map(object({
    description            = optional(string)
    execution_mode         = optional(string, "remote") # remote, local or agent
    terraform_version      = optional(string)           # version or constraint, e.g. "~> 1.16"
    auto_apply             = optional(bool, false)
    auto_apply_run_trigger = optional(bool, false) # also auto-apply runs started by run triggers
    working_directory      = optional(string)
    trigger_patterns       = optional(list(string))
    tags                   = optional(map(string), {})
    env_vars               = optional(map(string), {})  # environment variables, e.g. TFC_AZURE_* for dynamic credentials
    remote_state_consumers = optional(list(string), []) # workspaces of this project that may read this workspace's outputs
    auto_destroy = optional(object({                    # schedule a destroy run; set exactly one field
      at               = optional(string)               # RFC3339 time, e.g. "2026-10-31T18:00:00Z"
      after_inactivity = optional(string)               # e.g. "3d" or "12h" after the last run
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

  # Destroying a workspace whose outputs other workspaces read would break them
  validation {
    condition = alltrue([
      for ws in values(var.workspaces) : ws.auto_destroy == null || length(ws.remote_state_consumers) == 0
    ])
    error_message = "auto_destroy cannot be set on a workspace with remote_state_consumers."
  }
}
