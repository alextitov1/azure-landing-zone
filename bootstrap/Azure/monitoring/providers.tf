terraform {
  cloud {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

# Uses the subscription from the tenant YAML's monitoring section
provider "azurerm" {
  features {}
  subscription_id = try(local.monitoring.subscription_id, null)
  tenant_id       = local.tenant_config.entraid_tenant_id
}
