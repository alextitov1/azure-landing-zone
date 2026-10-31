#!/usr/bin/env bash

# Runs terraform <command> against the HCP Terraform tier-0 workspace (hcp_tf_bootstrap_r0),
# using the API token stored in 1Password.
# Usage: ./bootstrap-hcp.sh init|plan|apply

set -euo pipefail  # stop if a secret cannot be read from 1Password

TOKEN=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io="$TOKEN"   # cloud block (state)
export TFE_TOKEN="$TOKEN"                   # tfe provider

# Secrets for the tier-1 workspace are listed in config.yaml (secrets:) and read by Terraform itself.

terraform -chdir="$(dirname "$0")" "$@"
