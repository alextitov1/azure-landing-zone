# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

backend "azurerm" {
  resource_group_name  = "tf-githubaction"
  storage_account_name = "tfgithubactions"
  container_name       = "tfstateghactions"
  key                  = "tfstateghactions.tfstate"
}



