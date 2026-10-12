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
    env_vars               = optional(map(string), {}) # environment variables, e.g. TFC_AZURE_* for dynamic credentials
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
}
