# Windows jumpbox to reach private endpoints from inside the network: Entra ID sign-in, a public IP for RDP and
# outbound access, and tools installed at the first boot.

# Names: <type>-<workload>-<env>-<region>-<nn>, see ESLZ/README.md
module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"

  suffix               = var.name_suffix
  instance             = var.instance
  instance_format      = "%02d"
  unique_length        = 0
  custom_override_file = "${path.module}/naming-overrides.json"
}

locals {
  names = module.naming.names
}

module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.21.0"

  name                = local.names.compute_virtual_machine.name
  computer_name       = var.config.computer_name
  resource_group_name = var.resource_group_name
  location            = var.location
  zone                = try(var.config.zone, null)
  tags                = var.tags
  enable_telemetry    = false

  os_type                = "Windows"
  sku_size               = var.config.vm_size
  source_image_reference = var.config.image
  patch_mode             = try(var.config.patch_mode, null)
  os_disk = {
    name                 = local.names.disk_managed_disk_o.name
    caching              = "ReadWrite"
    storage_account_type = var.config.os_disk.storage_account_type
    disk_size_gb         = try(var.config.os_disk.size_gb, null)
  }

  # Trusted Launch. Encryption at host would need the Microsoft.Compute/EncryptionAtHost feature on the subscription.
  secure_boot_enabled        = true
  vtpm_enabled               = true
  encryption_at_host_enabled = false

  # People sign in with Entra ID. The local administrator is a fallback whose password stays in the state:
  # `az vm user update` sets a new one.
  account_credentials = {
    admin_credentials = {
      username                           = var.config.admin_username
      generate_admin_password_or_ssh_key = true
    }
  }

  # AADLoginForWindows signs the VM in to Entra ID with this identity
  managed_identities = { system_assigned = true }

  # The public IP is the VM's way out too: new subnets have no default outbound access
  network_interfaces = {
    primary = {
      name = local.names.network_interface.name
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_subnet_resource_id = var.subnet_id
          create_public_ip_address      = true
          public_ip_address_name        = local.names.public_ip_address.name
        }
      }
    }
  }

  # Run by the CustomScriptExtension below, as in archive/Apps/virtual-machine
  custom_data = base64encode(templatefile("${path.module}/bootstrap.ps1.tftpl", {
    packages = try(var.config.packages, [])
  }))

  extensions = {
    entra_sign_in = {
      name                       = "AADLoginForWindows"
      publisher                  = "Microsoft.Azure.ActiveDirectory"
      type                       = "AADLoginForWindows"
      type_handler_version       = "2.0"
      auto_upgrade_minor_version = true
      deploy_sequence            = 1
    }
    bootstrap = {
      name                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type                       = "CustomScriptExtension"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      deploy_sequence            = 2
      # A package download that fails shouldn't fail the apply; the log is C:\AzureData\bootstrap.log
      failure_suppression_enabled = true
      settings = jsonencode({
        commandToExecute = "powershell.exe -ExecutionPolicy Bypass -Command \"Copy-Item C:\\AzureData\\CustomData.bin C:\\AzureData\\bootstrap.ps1 -Force; & C:\\AzureData\\bootstrap.ps1 *> C:\\AzureData\\bootstrap.log\""
      })
    }
  }
}
