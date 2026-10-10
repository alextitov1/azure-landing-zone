# Injected by hcp-tier0. All other settings live in YAML (../config, ./projects).
variable "github_app_installation_id" {
  description = "HCP Terraform GitHub App installation ID, for VCS-driven workspaces."
  type        = string
}
