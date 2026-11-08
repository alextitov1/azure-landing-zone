terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13" # used by Azure/avm-ptn-alz-sub-vending
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
  }
}
