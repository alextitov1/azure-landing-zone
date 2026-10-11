terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    onepassword = {
      source = "1Password/onepassword"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
