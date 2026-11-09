output "resource_id" {
  description = "Resource ID of the VM."
  value       = module.virtual_machine.resource_id
}

output "name" {
  description = "Name of the VM resource."
  value       = module.virtual_machine.name
}

output "computer_name" {
  description = "Windows host name: the name to connect to with Entra ID sign-in."
  value       = var.config.computer_name
}

output "public_ip_address" {
  description = "Public IP address for RDP."
  value       = one(values(module.virtual_machine.public_ips)).ip_address
}

output "private_ip_address" {
  description = "Private IP address in the subnet."
  value       = one(values(module.virtual_machine.network_interfaces)).private_ip_address
}

output "admin_username" {
  description = "Local administrator, a fallback for Entra ID sign-in."
  value       = var.config.admin_username
}
