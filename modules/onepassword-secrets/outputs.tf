output "values" {
  description = "Map of reference => secret value."
  value       = local.values
  sensitive   = true
  ephemeral   = true
}
