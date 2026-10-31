variable "organization" {
  description = "Name of the HCP Terraform organization."
  type        = string
}

variable "projects" {
  description = "The `projects:` map of a tier's config.yaml: { <project> = { description, workspaces = { <workspace> = {...} } } }."
  type        = any
}
