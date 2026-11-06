terraform {
  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.22" # used by Azure/avm-ptn-alz
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
  }
}
