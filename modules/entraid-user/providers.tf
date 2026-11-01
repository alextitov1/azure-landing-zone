terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    onepassword = {
      source = "1Password/onepassword"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
