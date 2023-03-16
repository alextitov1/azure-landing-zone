terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.46.0"
    }
  }
  backend "azurerm" {
    # using Service Principal
    use_azuread_auth = true
    container_name   = "firewall"
    key              = "terraform.tfstate"

  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}