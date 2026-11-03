#!/usr/bin/env bash

# Runs terraform <command> for tier 0 of an Entra ID tenant, with secrets from 1Password.
# Usage: ./bootstrap-azure.sh <tenant> init|plan|apply   (tenant: a directory in tenants/, e.g. 4esnok_vs)

set -euo pipefail  # stop if a secret cannot be read from 1Password

TENANT="${1:?usage: $0 <tenant> <terraform command>}"
DIR="$(dirname "$0")"
[[ -f "$DIR/tenants/$TENANT/config.yaml" ]] || { echo "no tenants/$TENANT/config.yaml" >&2; exit 1; }

# HCP Terraform project and workspace of each tenant (see HCP/config.yaml)
case "$TENANT" in
  4esnok_vs)
    TF_CLOUD_PROJECT="4esnok_vs_r0"
    TF_WORKSPACE="4esnok_vs_azure_bootstrap_r0"
    ;;
  4esnok_mail)
    TF_CLOUD_PROJECT="4esnok_mail_r0"
    TF_WORKSPACE="4esnok_mail_azure_bootstrap_r0"
    ;;
  *)
    echo "no settings for tenant $TENANT in $0" >&2
    exit 1
    ;;
esac
export TF_CLOUD_ORGANIZATION="4esnok"
export TF_CLOUD_PROJECT TF_WORKSPACE
export TF_VAR_tenant="$TENANT"

TF_TOKEN_app_terraform_io=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
export TF_TOKEN_app_terraform_io

# export TFE_TOKEN="$TF_TOKEN_app_terraform_io"

# Token for the 1Password Terraform provider, which stores user passwords. Read last: once exported, op itself
# would sign in with it.
OP_SERVICE_ACCOUNT_TOKEN=$(op read "op://cloud_r0/op_cloud_bootstrap_t0/credential")
export OP_SERVICE_ACCOUNT_TOKEN

terraform -chdir="$DIR" "${@:2}"
