variable "organization" {
  description = "Name of the HCP Terraform organization."
  type        = string
}

variable "projects" {
  description = "The `projects:` map of a tier's config.yaml: { <project> = { description, workspaces = { <workspace> = {...} } } }."
  type        = any
}

variable "run_trigger_workspace" {
  description = "Name of the workspace that runs this configuration, re-run after each apply of a workspace whose outputs `variables:` reads; null for none."
  type        = string
  default     = null
}
