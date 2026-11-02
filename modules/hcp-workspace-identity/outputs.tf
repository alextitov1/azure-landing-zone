output "workspace_variables" {
  value       = { for key, v in local.client_id_variables : key => v.app }
  description = "The application whose client ID each workspace variable holds, by <workspace>/<variable>"
}
