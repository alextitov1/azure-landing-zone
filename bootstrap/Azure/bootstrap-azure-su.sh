#!/usr/bin/env bash

# This script runs terraform <command> with submitted secrets from onepassword

# Terraform cloud organization, project and workspace https://app.terraform.io/app/4esnok/workspaces
export TF_CLOUD_ORGANIZATION="4esnok"
export TF_CLOUD_PROJECT="4esnok_su"
export TF_WORKSPACE="entraid_bootstrap"

export TF_VAR_tenant_yaml_path="../tenants/admin.4esnok.su-vs.yaml"

# Token for the 1Password Terraform provider; allows Terraform to access the Azure vault in 1Password to retrieve/store secrets.
export TF_VAR_onepassword_service_account_token=$(op read "op://IT/op_azure_t1_rw_t1/credential")

# token for terraform hcl
export TF_TOKEN_app_terraform_io=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")

# env | sort

terraform -chdir=./terraform "$@"