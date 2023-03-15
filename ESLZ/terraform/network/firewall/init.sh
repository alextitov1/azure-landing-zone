
export ARM_CLIENT_ID=
export ARM_CLIENT_SECRET=
export ARM_SUBSCRIPTION_ID=
export ARM_TENANT_ID=


launchpad_dir="../../launchpad/"

terraform -chdir=$launchpad_dir init

rg_storageaccount_name=$(terraform -chdir=$launchpad_dir output -raw rg_storageaccount_name)
st_stfiles_name=$(terraform -chdir=$launchpad_dir output -raw st_stfiles_name)

terraform init \
    -backend-config="resource_group_name=$rg_storageaccount_name" \
    -backend-config="storage_account_name=$st_stfiles_name"