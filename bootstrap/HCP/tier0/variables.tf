# Injected by bootstrap-hcp.sh from 1Password. All other settings live in ../config/organization.yaml.
variable "github_token" {
  description = "GitHub fine-grained token for the organization's OAuth VCS connection (see README, step 5)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_token) > 0
    error_message = "github_token is empty; check the 1Password item read by bootstrap-hcp.sh."
  }
}
