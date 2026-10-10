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

## Applications

The `applications` section of a tenant YAML file lists app registrations. Each entry creates the app registration and its enterprise application (service principal), and can set:

| Key | Purpose |
|---|---|
| `description` | Description of the app registration |
| `owners` | User principal names of users from the `users` section |
| `federated_credentials` | Workload identity federation: `name`, `issuer`, `subject`, optional `audiences` (default `api://AzureADTokenExchange`) and `description` |
| `graph_app_roles` | Microsoft Graph application permissions, e.g. `Directory.Read.All` (admin consent is granted by the assignment) |
| `entraid_role_names` | Permanent Entra ID directory roles for the service principal |
| `client_secret` | Client secret stored in 1Password: `key_vault_name` (vault), optional `rotation_days` (default 180) and `overlap_days` (default 30) |

Prefer `federated_credentials` where the caller supports OIDC. For a client secret, the 1Password item is titled after the application, with the client ID as username, the secret as password and the tenant and expiry in its notes. A new secret is created on the first apply after `rotation_days`; it is stored in 1Password before the old secret is deleted, so anything holding the old value must re-read it from 1Password. The secret expires `overlap_days` after its rotation date, which leaves time to run that apply. Like user passwords, the secret is also kept in the Terraform state.

Groups can list applications as `members` by display name, next to users by user principal name. The `applications` output shows each application's client ID and service principal object ID.

### HCP Terraform OIDC

HCP Terraform workspaces sign in to Azure with [dynamic provider credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration) instead of a client secret. Each workspace gets two applications, one for plan runs (read-only) and one for apply runs, each with a federated credential:

- issuer: `https://app.terraform.io`
- subject: `organization:<org>:project:<project>:workspace:<workspace>:run_phase:<plan|apply>`

The workspace's `TFC_AZURE_*` variables are set by `bootstrap/HCP/tier1` from the `azure_oidc` block of the workspace in its project YAML.

### Moving this configuration (Azure tier 0) to remote runs

1. Run `./bootstrap-azure-su.sh apply` locally, signed in with `az login` as a Global Administrator. This creates the `hcp-4esnok_su_entraid_bootstrap-plan` and `-apply` applications.
2. Copy their client IDs from `terraform output applications` into the `azure_oidc` block of `4esnok_su_entraid_bootstrap` in `bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`, and apply tier 1.
3. Move the state from the current workspace (`4esnok_su/entraid_bootstrap`) to `4esnok_su_azure/4esnok_su_entraid_bootstrap`, and point `bootstrap-azure-su.sh` at it.
4. Add the remaining inputs to the workspace: `tenant_yaml_path` (Terraform variable) and `TF_VAR_onepassword_service_account_token` (sensitive environment variable). Set its working directory to `bootstrap/Azure/terraform`, so `../tenants` is uploaded with the configuration.
5. Switch `execution_mode` to `remote` in the project YAML.

The tier-0 apply application can change users, groups, applications and directory roles, so it controls the tenant. Restrict who can queue applies on its workspace and keep a break-glass Global Administrator account that is not managed by Terraform.
