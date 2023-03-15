terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.46.0"
    }
  }
  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
  subscription_id = var.subscription_id
}