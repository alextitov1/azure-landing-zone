#!/usr/bin/env bash

# Runs terraform <command> against the HCP Terraform tier-0 workspace (hcp-tier0),
# using the API token stored in 1Password.
# Usage: ./bootstrap-hcp.sh init|plan|apply

set -euo pipefail  # stop if a secret cannot be read from 1Password

TOKEN=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io="$TOKEN"   # cloud block (state)
export TFE_TOKEN="$TOKEN"                   # tfe provider

# GitHub token for the OAuth VCS connection used by tier-1 workspaces
TF_VAR_github_token=$(op read "op://IT/hcp_terraform_tier1/credential")
export TF_VAR_github_token

terraform -chdir=./tier0 "$@"
