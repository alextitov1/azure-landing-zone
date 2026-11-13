output "jumpbox" {
  description = "The jumpbox's host name (to connect to with Entra ID), public and private IP addresses and local administrator."
  value = {
    computer_name      = module.jumpbox.computer_name
    fqdn               = module.jumpbox.fqdn
    public_ip_address  = module.jumpbox.public_ip_address
    private_ip_address = module.jumpbox.private_ip_address
    admin_username     = module.jumpbox.admin_username
  }
}
