output "vm_all_properties" {
  value     = nonsensitive(module.windows_vm)
  sensitive = true

}

output "vm_data" {
  value = {
    dns_name            = resource.azurerm_dns_a_record.vm01-public-dns-name.fqdn
    name                = module.windows_vm.name
    public_ip_address   = module.windows_vm.public_ips["network_interface_1-ip_configuration_1"].ip_address
    username            = module.windows_vm.admin_username
    password            = module.windows_vm.admin_password
  }
  sensitive = true
}