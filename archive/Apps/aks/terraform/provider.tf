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
  subscription_id = "44b9d159-d353-477f-b94f-5ce0f3bd33f1"
}