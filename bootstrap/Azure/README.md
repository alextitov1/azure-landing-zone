# Bootstrap Azure (EntraID) Tenant.

The bootstrap process for a newly created azure tenant creates admin users, and service accounts (aka service principals). User accounts are stored in 1Password, and service accounts are configured with OIDC federated credentials, so HCP Terraform runs can sing in to Azure without a client secret.

The bootstraping requires configuring tenant/*.yaml files, and running the bootstrap-*.sh script. To apply configuration.

The bootstrap process assumnd to be run only once for a newly created tenant. The later changes (Tier 1 and above) are done through the HCP Terraform pipeline.

>NOTE: HCP workspace e.g. (`4esnok_su_entraid_t0_t1`) is set up in two phases

Each tenant is described by a YAML file in `tenants/`. The Terraform configuration in `terraform/` (Azure tier 0) manages:

- users, including break-glass accounts, and groups (static or dynamic, with group-based licensing)
- applications (app registrations and service principals) with OIDC federated credentials or client secrets
- directory roles, PIM eligible roles, administrative units and access packages
- tenant settings: security defaults, Conditional Access, authorization policy, cross-tenant access, custom domains and B2B guests

`monitoring/` is a separate configuration that sends Entra ID logs to Log Analytics and alerts on break-glass use.

## How it works

The bootstrap process creates admin users, groups and service principals in the EntraID. These identities are used to manage azure resources and other less privileged users. Since these are the first identities created in the tenant, before any CI/CD pipelines or other automation is in place, the bootstrap process in done manually by executing a shell script.


## Prerequisites
- Terraform CLI
- 1Password + 1Password CLI and access to the organization's vault(s)
- Azure CLI

## Tenant YAML reference

Every section is optional. Features marked P1 or P2 need that Entra ID licence; leave them out of a tenant without it. The tenant files show each section, commented out where it does not apply.

| Section | What it manages | Licence | Graph application permissions (tier-0 apply identity) |
|---|---|---|---|
| `users` | Users; `break_glass`, `password_length`, `account_enabled`, `usage_location`, `manager`, direct `entraid_role_names` | Free | `User.ReadWrite.All`, `RoleManagement.ReadWrite.Directory` |
| `groups` | Security groups, `description` and members (users, applications, guests); `dynamic_rule`; `licenses` | Free; dynamic groups and licensing P1 | `Group.ReadWrite.All`; licensing `LicenseAssignment.ReadWrite.All`, `Organization.Read.All` |
| `applications` | App registrations, see below | Free | `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All` |
| `tenant_settings.security_defaults` | Security defaults on or off; applied in remote runs only, because Azure CLI tokens lack `Policy.ReadWrite.ConditionalAccess` | Free | `Policy.Read.All`, `Policy.ReadWrite.ConditionalAccess` |
| `tenant_settings.authorization_policy` | Default user and guest permissions (Graph property names) | Free | `Policy.ReadWrite.Authorization` |
| `named_locations`, `authentication_strength_policies`, `conditional_access_policies` | Conditional Access | P1 | `Policy.Read.All`, `Policy.ReadWrite.ConditionalAccess` |
| `pim_roles` | PIM eligible directory roles and their maximum activation `duration` | P2 | `RoleEligibilitySchedule.ReadWrite.Directory`, `RoleManagementPolicy.ReadWrite.Directory` |
| `access_package_catalogs`, `access_packages` | Access packages with approval and access reviews | P2 or ID Governance | `EntitlementManagement.ReadWrite.All` |
| `administrative_units` | Administrative units, members and scoped roles | Free; unit admins P1 | `AdministrativeUnit.ReadWrite.All`, `RoleManagement.ReadWrite.Directory` |
| `guests` | B2B guest invitations | Free | `User.Invite.All` |
| `cross_tenant_access` | Cross-tenant access default and partners (Graph property names) | Free | `Policy.ReadWrite.CrossTenantAccess` |
| `domains` | Additional custom domains and their verification | Free | `Domain.ReadWrite.All` |
| `monitoring` | Used by `monitoring/` only | Sign-in logs P1 | Azure RBAC on the subscription; Global or Security Administrator for the Entra ID diagnostic setting |

Add a permission to the tier-0 apply application only when the tenant uses that section. The plan application needs the read equivalents (`Directory.Read.All` and `Policy.Read.All` cover most of them).

Settings that every tenant already has (`tenant_settings`, `cross_tenant_access.default`, PIM activation duration) are updated in place: taking them out of the YAML leaves the tenant as it is.

### Naming

Names are lowercase with hyphens and carry no tenant name. The tier follows the Microsoft Enterprise Access Model:
`t0` control plane (Entra ID, root management group), `t1` management plane (subscriptions, platform), `t2` workloads and data.
The plan fails on names that do not match.

| Object | Pattern | Examples |
|---|---|---|
| Groups | `sg-<tier>-<target>-<scope>-<role>`; target is `entra` (directory roles), `az` (Azure RBAC), `app` (application access) or `org` (teams); `-dyn` for dynamic groups; `m365` instead of `sg` for Microsoft 365 groups | `sg-t0-entra-tenant-globaladmin`, `sg-t2-az-aks-admin`, `sg-t2-org-developers-dyn` |
| Applications | `<type>-<tier>-<consumer>-<target>-<access>`; type is `sp` (automation), `app` (users sign in) or `mi` (managed identity) | `sp-t0-hcp-entraid-bootstrap-apply`, `sp-t1-gha-public-dns-deploy` |

Groups and applications are keyed by display name, so renaming one recreates it with a new object ID.

### Break-glass accounts

A user with `break_glass: true` is an emergency access account. Each tenant has two, cloud-only on its `onmicrosoft.com` domain, with a permanent Global Administrator role and a 64-character password stored in 1Password (the plan fails if `store_password_in_key_vault` is not set). They are excluded from every Conditional Access policy automatically, and `monitoring/` alerts on any sign-in or change they make.

After the first apply:

1. Sign in with each account, register a FIDO2 security key (security defaults and Azure's mandatory MFA still require MFA for them), and keep the keys in separate safe places.
2. Test each sign-in at least every few months.

### MFA

- **admin.4esnok.su (free):** `tenant_settings.security_defaults: true`. All users must register MFA; admins are always prompted.
- **mail.4esnok.su (P1):** security defaults are off and replaced by Conditional Access: CA001 blocks legacy authentication and CA002 requires MFA for all users, both enabled; CA003 requires phishing-resistant MFA for admin roles in report-only mode. Switch CA003 to `enabled` once admins have FIDO2 keys, after checking its report-only results in the sign-in logs.

Users register their own MFA methods at first sign-in; Terraform cannot do this for them.

### Monitoring

`monitoring/` reads the same tenant YAML. To enable it:

1. Uncomment and fill in the tenant's `monitoring` section: subscription, resource group, workspace, alert email. Keep `log_categories` to `AuditLogs` in a tenant without P1.
2. Add an HCP Terraform workspace for it in `bootstrap/HCP/tier1` with `execution_mode: local`.
3. Run it locally as a Global Administrator (`az login`):

```sh
export TF_CLOUD_ORGANIZATION=4esnok TF_CLOUD_PROJECT=<project> TF_WORKSPACE=<monitoring workspace>
export TF_TOKEN_app_terraform_io=$(op read "op://IT/terraform_hcp_4esnok_tier0/credential")
terraform -chdir=monitoring init
terraform -chdir=monitoring apply -var tenant_yaml_path=../tenants/<tenant>.yaml
```

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

The workspace `4esnok_su_entraid_t0_t1` is set up in two phases, controlled by its entry in `bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`.

**Phase 1 (bootstrap).** The workspace has `execution_mode: local` and only stores state.
Run `./bootstrap-azure-su.sh apply`, signed in with `az login` as a Global Administrator. This creates the
`sp-t0-hcp-entraid-bootstrap-plan` and `-apply` applications; their client IDs are in the `applications` output.
Security defaults are skipped in this phase.

**Phase 2 (pipeline).**
1. In the project YAML, replace `execution_mode: local` with the phase-2 block and merge.
   Tier 1 reads the client IDs of the applications named in `azure_oidc` from the `applications` output, sets the `TFC_AZURE_*` variables, sets
   `TF_VAR_onepassword_service_account_token` from 1Password (vault `azure_t1`), and links the
   workspace to this repository with working directory `bootstrap/Azure/terraform`.
2. Runs now execute in HCP Terraform as the OIDC applications and start on merge to `main`.
   `./bootstrap-azure-su.sh plan` still works as a speculative plan; `apply` only runs through a merge.

The tier-0 apply application can change users, groups, applications and directory roles, so it controls the tenant. Restrict who can queue applies on its workspace and keep a break-glass Global Administrator account that is not managed by Terraform.
