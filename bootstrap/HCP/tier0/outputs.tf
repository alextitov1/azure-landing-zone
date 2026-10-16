output "tier1_workspace_url" {
  description = "URL of the tier-1 pipeline workspace."
  value       = module.hcp.workspace_html_urls["hcp-tier1"]
}

output "autodestroyer_token" {
  description = "Owners team token for hcp-autodestroyer; copy it into that app's secret store after each rotation."
  value       = tfe_team_token.autodestroyer.token
  sensitive   = true
}
