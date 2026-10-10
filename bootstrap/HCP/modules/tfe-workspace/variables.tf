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

variable "workspaces" {
  description = "Map of workspaces to create within the project. Key is the workspace name."
  type = map(object({
    description       = optional(string)
    execution_mode    = optional(string, "remote") # remote, local or agent
    terraform_version = optional(string)           # version or constraint, e.g. "~> 1.16"
    auto_apply        = optional(bool, false)
    working_directory = optional(string)
    trigger_patterns  = optional(list(string))
    tags              = optional(map(string), {})
    vcs_repo = optional(object({
      identifier                 = string
      branch                     = optional(string)
      github_app_installation_id = string
    }))
  }))
  default = {}
}
