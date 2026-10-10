# Bootstrap Azure (EntraID) Tenant.

- create users and groups in EntraID
- assign PIM roles to groups
- create service principals

## How it works

The bootstrap process creates admin users, groups and service principals in the EntraID. These identities are used to manage azure resources and other less privileged users. Since these are the first identities created in the tenant, before any CI/CD pipelines or other automation is in place, the bootstrap process in done manually by executing a shell script.


## Prerequisites
- Terraform CLI
- 1Password + 1Password CLI and access to the organization's vault(s)
- Azure CLI

## HCP Terraform workload identities (OIDC)

HCP Terraform workspaces sign in to Azure with [dynamic provider credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration) instead of a client secret. The `hcp_workload_identities` section of a tenant YAML file lists the workspaces; for each one the `hcp_workload_identity` module creates:

- two app registrations and service principals, `hcp-<workspace>-plan` and `hcp-<workspace>-apply`, so plans run with read-only access
- a federated credential on each, trusting `organization:<org>:project:<project>:workspace:<workspace>:run_phase:<plan|apply>` from `https://app.terraform.io`
- Microsoft Graph application permissions (`graph_app_roles`) per phase
- the workspace environment variables `TFC_AZURE_PROVIDER_AUTH`, `TFC_AZURE_PLAN_CLIENT_ID`, `TFC_AZURE_APPLY_CLIENT_ID`, `ARM_TENANT_ID` and, when `subscription_id` is set, `ARM_SUBSCRIPTION_ID`

The workspace must exist before this runs; workspaces are created in `bootstrap/HCP/tier1`. Do not set the same variables there, or the two configurations will fight over them.

### Moving this configuration (Azure tier 0) to remote runs

1. Run `./bootstrap-azure-su.sh apply` locally, signed in with `az login` as a Global Administrator. This creates the tier-0 identities and sets their variables on `4esnok_su_entraid_bootstrap`.
2. Add the remaining inputs to the workspace as variables: `tenant_yaml_path` (Terraform), and `TF_VAR_onepassword_service_account_token` and `TFE_TOKEN` (sensitive environment variables).
3. Set the workspace's working directory to `bootstrap/Azure/terraform`, so `../tenants` is uploaded with the configuration.
4. Switch `execution_mode` to `remote` in `bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`.

The tier-0 apply identity can change users, groups, app registrations and directory roles, so it controls the tenant. Restrict who can queue applies on its workspace and keep a break-glass Global Administrator account that is not managed by Terraform.
