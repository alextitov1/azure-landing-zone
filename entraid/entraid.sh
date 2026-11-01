#!/usr/bin/env bash

# Runs terraform <command> for tier 1 of an Entra ID tenant, with secrets from 1Password.
# Usage: ./entraid.sh <tenant> init|plan|apply   (tenant: a directory in tenants/, e.g. 4esnok_vs)

set -euo pipefail  # stop if a secret cannot be read from 1Password

TENANT="${1:?usage: $0 <tenant> <terraform command>}"
DIR="$(dirname "$0")"
[[ -f "$DIR/tenants/$TENANT/config.yaml" ]] || { echo "no tenants/$TENANT/config.yaml" >&2; exit 1; }

# HCP Terraform workspace, named after the tenant (see HCP/config.yaml)
export TF_CLOUD_ORGANIZATION="4esnok"
export TF_CLOUD_PROJECT="${TENANT}_r1"
export TF_WORKSPACE="${TENANT}_entraid_mgmt_r1"
export TF_VAR_tenant="$TENANT"

# Token for the 1Password Terraform provider, which stores user passwords and client secrets in the Azure vault.
TF_VAR_onepassword_service_account_token=$(op read "op://IT/op_azure_t1_rw_t1/credential")
export TF_VAR_onepassword_service_account_token

TF_TOKEN_app_terraform_io=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io

terraform -chdir="$DIR" "${@:2}"
