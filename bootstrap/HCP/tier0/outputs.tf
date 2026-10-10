output "tier1_workspace_url" {
  description = "URL of the tier-1 pipeline workspace."
  value       = module.hcp.workspace_html_urls["hcp-tier1"]
}
