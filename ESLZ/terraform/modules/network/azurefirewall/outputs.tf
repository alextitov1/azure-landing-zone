
output "firewall_id" {
  value       = azurerm_firewall.this.id
}


output "virtual_hub_firewall_private_ip" {
  value = try(azurerm_firewall.this.virtual_hub[0].private_ip_address, null)
}

output "virtual_hub_firewall_public_ips" {
  value = try(azurerm_firewall.this.virtual_hub[0].public_ip_addresses,null)
}
