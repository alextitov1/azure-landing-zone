#!/usr/bin/env bash

# Runs terraform <command> against the HCP Terraform tier-0 workspace (hcp-tier0),
# using the API token stored in 1Password.
# Usage: ./bootstrap-hcp.sh init|plan|apply

TOKEN=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io="$TOKEN"   # cloud block (state)
export TFE_TOKEN="$TOKEN"                   # tfe provider

terraform -chdir=./tier0 "$@"
