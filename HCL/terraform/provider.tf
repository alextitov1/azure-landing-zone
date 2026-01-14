terraform {
  required_providers {
    tfe = {
      source = "hashicorp/tfe"
    }
  }
  cloud {
    organization = "4esnok"
    
    workspaces {
      name = "4esnok_workspaces"
    }
    
  }
}

provider "tfe" {
  hostname = "app.terraform.io"
}
