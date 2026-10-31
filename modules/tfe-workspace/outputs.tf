output "project_id" {
  description = "The ID of the created project."
  value       = tfe_project.this.id
}

output "workspace_ids" {
  description = "Map of workspace names to their IDs."
  value       = { for k, v in tfe_workspace.this : k => v.id }
}

output "workspace_html_urls" {
  description = "Map of workspace names to their HTML URLs."
  value       = { for k, v in tfe_workspace.this : k => v.html_url }
}
