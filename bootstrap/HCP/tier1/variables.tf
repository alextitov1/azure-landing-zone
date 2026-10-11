# Injected by hcp-tier0. All other settings live in YAML (../config, ./projects).
variable "github_oauth_token_id" {
  description = "OAuth token ID of the organization's GitHub VCS connection, for VCS-driven workspaces."
  type        = string
}
