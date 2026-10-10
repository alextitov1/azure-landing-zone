output "workspace_urls" {
  description = "URLs of the workspaces managed by tier 1."
  value       = merge([for p in module.project : p.workspace_html_urls]...)
}
