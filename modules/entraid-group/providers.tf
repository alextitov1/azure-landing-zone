terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    msgraph = {
      source = "microsoft/msgraph"
    }
  }
}
