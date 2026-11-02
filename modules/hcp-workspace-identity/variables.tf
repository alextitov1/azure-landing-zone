variable "organization" {
  type        = string
  default     = null
  description = "HCP Terraform organization (hcp_organization in the tenant config); needed when there is a workspace"
}

variable "applications" {
  type        = map(object({ client_id = string }))
  description = "Entra ID applications by display name (the applications output of modules/entraid-tenant)"
}

variable "config" {
  type = list(object({
    display_name = string
    hcp_workspaces = optional(list(object({
      name      = string
      run_phase = optional(string) # plan or apply; unset: both phases (TFC_AZURE_RUN_CLIENT_ID)
    })), [])
  }))
  description = "The applications in the tenant config (entra_id.applications); only their hcp_workspaces are used"

  validation {
    condition     = alltrue([for ws in flatten(var.config[*].hcp_workspaces) : ws.run_phase == null || contains(["plan", "apply"], coalesce(ws.run_phase, "x"))])
    error_message = "hcp_workspaces[].run_phase must be plan or apply, or unset for both."
  }
}
