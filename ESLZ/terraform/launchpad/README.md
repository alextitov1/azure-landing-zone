manages AzureRM provider backend (resource groups, storage accounts, blobs)

```
az account set --subscription 22222
```

```
az account list-locations -o table
```

```sh
terraform init     # -backend-config="workspace_dir=sandbox"
terraform plan -var-file=example.tfvars
terraform apply -var-file=example.tfvars -auto-approve
```

Storage Blob Data Contributor role to the account
