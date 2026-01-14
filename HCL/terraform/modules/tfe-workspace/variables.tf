variable "organization_name" {
  description = "Name of the TFE organization."
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

variable "workspaces" {
  description = "Map of workspaces to create within the project. Key is the workspace name."
  type = map(object({
    description       = optional(string)
    auto_apply        = optional(bool, false)
    working_directory = optional(string)
    vcs_repo = optional(object({
      identifier     = string
      branch         = optional(string)
      oauth_token_id = string
    }))
    tag_names = optional(list(string), [])
  }))
  default = {}
}

variable "execution_mode" {
  description = "The execution mode for the workspaces (remote, local, agent)."
  type        = string
  default     = "remote"
}
