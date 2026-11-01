#!/usr/bin/env bash

# Runs terraform <command> for tier 0 of an Entra ID tenant, with secrets from 1Password.
# Usage: ./bootstrap-azure.sh <tenant> init|plan|apply   (tenant: a directory here, e.g. 4esnok_vs)

set -euo pipefail  # stop if a secret cannot be read from 1Password

TENANT="${1:?usage: $0 <tenant> <terraform command>}"
DIR="$(dirname "$0")/$TENANT"
[[ -f "$DIR/terraform.tf" ]] || { echo "no tenant directory $TENANT" >&2; exit 1; }

TF_TOKEN_app_terraform_io=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io

# Token for the 1Password Terraform provider, which stores user passwords. Read last: once exported, op itself
# would sign in with it.
OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://cloud_r0/op_cloud_bootstrap_t0/credential")
export OP_SERVICE_ACCOUNT_TOKEN

terraform -chdir="$DIR" "${@:2}"
