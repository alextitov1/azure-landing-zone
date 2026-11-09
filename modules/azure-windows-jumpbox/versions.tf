terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # used by Azure/avm-res-compute-virtualmachine
    }
  }
}
