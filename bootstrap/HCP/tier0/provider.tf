terraform {
  required_version = "~> 1.16"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }

  # The only workspace created manually (CLI-driven, execution mode: Local).
  # The cloud block cannot read locals, so the organization is repeated here.
  cloud {
    organization = "4esnok"

    workspaces {
      name = "hcp-tier0"
    }
  }
}

provider "tfe" {
  hostname     = "app.terraform.io"
  organization = local.config.organization
}
