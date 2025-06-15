terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"

  }
}

provider "azurerm" {
  features {}
  subscription_id = "b63ed8a5-399c-4375-9365-9c5edb7deab7"
}