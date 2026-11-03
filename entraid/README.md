# Entra ID tenants (tier 1)

This directory manages the day-two configuration of each Entra ID tenant: users, groups, applications, Conditional
Access, PIM, access packages, administrative units, guests, cross-tenant access, domains, and management groups with
Azure Policy. Admin and break-glass users, tier-0 groups and the intermediate root management group are in tier 0,
see [bootstrap/Azure](../bootstrap/Azure/README.md).

```
terraform.tf               reads tenants/<tenant>/config.yaml; uses ../modules/entraid-tenant (shared with tier 0)
management_groups.tf       management groups, Azure Policy and Azure RBAC (Azure/avm-ptn-alz)
entraid.sh                 ./entraid.sh <tenant> init|plan|apply
tenants/<tenant>/
  config.yaml              the tenant's tier-1 config
  lib/                     the tenant's Azure Landing Zones library
```

## Day-two operations

Each tenant has an HCP Terraform workspace `<tenant>_entraid_directory_r1` (project `<tenant>_r1`, see
[HCP/config.yaml](../HCP/config.yaml)). The plan fails if the tenant signed in to is not the config's
`entraid_tenant_id`.

### Remote runs

`4esnok_vs`: open a pull request that changes `tenants/<tenant>/` or the shared code for a speculative plan; merge
to `main`, then confirm the apply in HCP Terraform (no auto-apply). Runs sign in with dynamic credentials: plan runs
as `sp-hcp-entraid-directory-r1-plan`, apply runs as `sp-hcp-entraid-directory-r1-apply`. Tier 0 creates both and
their rights, and the workspace reads their client IDs, see
[Workspace variables and secrets](../HCP/README.md#workspace-variables-and-secrets).

Set these environment variables on the workspace by hand, in HCP Terraform:

| Variable | Value | Sensitive |
|---|---|---|
| `TF_VAR_tenant` | the tenant directory, e.g. `4esnok_vs` | no |
| `TF_VAR_onepassword_service_account_token` | the tier-1 1Password service account token (`op://IT/op_azure_t1_rw_t1/credential`) | yes |

### Local runs

`4esnok_mail`, whose workspace only stores state: edit the config, then plan and apply, signed in with `az login`
to that tenant:

```sh
./entraid.sh 4esnok_mail init
./entraid.sh 4esnok_mail plan
./entraid.sh 4esnok_mail apply
```

For a remote workspace the script can still run a speculative plan, with the workspace's own variables.

### Add a tenant

1. Bootstrap it in tier 0, see [bootstrap/Azure](../bootstrap/Azure/README.md).
2. Create `tenants/<tenant>/config.yaml`, and `tenants/<tenant>/lib/` with at least `alz_library_metadata.json`.
3. Add workspace `<tenant>_entraid_directory_r1` in project `<tenant>_r1` to [HCP/config.yaml](../HCP/config.yaml).

The directory name is the prefix of the tenant's HCP project and workspace names; it must start with a letter or digit
and contain only letters, digits and underscores.

## Tenant config reference

Both tiers read the same schema: `bootstrap/Azure/<tenant>/config.yaml` (tier 0) and `entraid/tenants/<tenant>/config.yaml` (tier 1).
At the top level are `entraid_tenant_id`, `entra_id` (every Entra ID section below except `management_groups`) and
`management_groups` (Azure). Every section is optional. Features marked P1 or P2 need that Entra ID licence; leave them out of a tenant without it. The tier-1 files show each section, commented out where it does not apply.

| Section | What it manages | Licence | Graph application permissions (apply identity) |
|---|---|---|---|
| `users` | Users, see [Users](#users) | Free | `User.ReadWrite.All`, `RoleManagement.ReadWrite.Directory` |
| `groups` | Security groups, `description` and members (users, applications, guests); `dynamic_rule`; `licenses` | Free; dynamic groups and licensing P1 | `Group.ReadWrite.All`; licensing `LicenseAssignment.ReadWrite.All`, `Organization.Read.All` |
| `applications` | App registrations, see below | Free | `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All` |
| `named_locations`, `authentication_strength_policies`, `conditional_access_policies` | Conditional Access | P1 | `Policy.Read.All`, `Policy.ReadWrite.ConditionalAccess` |
| `pim_roles` | PIM eligible directory roles and their maximum activation `duration` | P2 | `RoleEligibilitySchedule.ReadWrite.Directory`, `RoleManagementPolicy.ReadWrite.Directory` |
| `access_package_catalogs`, `access_packages` | Access packages with approval and access reviews | P2 or ID Governance | `EntitlementManagement.ReadWrite.All` |
| `administrative_units` | Administrative units, members and scoped roles | Free; unit admins P1 | `AdministrativeUnit.ReadWrite.All`, `RoleManagement.ReadWrite.Directory` |
| `guests` | B2B guest invitations | Free | `User.Invite.All` |
| `cross_tenant_access` | Cross-tenant access default and partners (Graph property names) | Free | `Policy.ReadWrite.CrossTenantAccess` |
| `domains` | Additional custom domains and their verification | Free | `Domain.ReadWrite.All` |
| `management_groups` | Management groups (Azure/avm-ptn-alz), Azure Policy and RBAC on them | Free | Azure on the intermediate root, from tier 0: Contributor, Resource Policy Contributor, Role Based Access Control Administrator (see [Management groups](#management-groups)) |

Grant a permission to an apply identity only when its tier uses that section. The plan application needs the read equivalents (`Directory.Read.All` and `Policy.Read.All` cover most of them).

Settings that every tenant already has (`cross_tenant_access.default`, PIM activation duration) are updated in place: taking them out of the config leaves the tenant as it is.

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

Each tenant has two emergency access accounts, cloud-only on its `onmicrosoft.com` domain, with a permanent Global Administrator role and a 64-character password stored in 1Password (`password.onepassword_vault`). They are created by tier 0, which tier 1 cannot reference, so tier-1 Conditional Access policies do not exclude them. An alert on their sign-ins is still to do (see the TODO list in [ESLZ/management_design.md](../ESLZ/management_design.md)).

After the first apply:

1. Sign in with each account, register a FIDO2 security key (security defaults and Azure's mandatory MFA still require MFA for them), and keep the keys in separate safe places.
2. Test each sign-in at least every few months.

### MFA

- **4esnok_vs (admin.4esnok.su, free):** security defaults on. All users must register MFA; admins are always prompted.
- **4esnok_mail (mail.4esnok.su, P1):** security defaults are off and replaced by Conditional Access: CA001 blocks legacy authentication and CA002 requires MFA for all users, both enabled; CA003 requires phishing-resistant MFA for admin roles in report-only mode. Switch CA003 to `enabled` once admins have FIDO2 keys, after checking its report-only results in the sign-in logs.

Security defaults and other tenant-wide settings (e.g. the authorization policy) are not managed by Terraform. Turn
security defaults off in the portal (**Entra ID → Overview → Properties → Manage security defaults**) before
applying Conditional Access policies.

Users register their own MFA methods at first sign-in; Terraform cannot do this for them.

### Management groups

`management_groups` is applied with the Azure Verified Module for Azure Landing Zones
([`Azure/avm-ptn-alz`](https://registry.terraform.io/modules/Azure/avm-ptn-alz/azurerm)):

- `architecture`: the hierarchy, an architecture definition in the tenant's `lib/<architecture>.alz_architecture_definition.yaml`
  (management group `id`, `display_name`, `parent_id`, `null` for the tenant root group, `exists: true` for a group
  created by tier 0, and `archetypes`;
  the built-in `empty` archetype has no policies). Policy comes from archetypes in the same library (see [Policy](#policy)).
- `location`: default location for policy managed identities.
- `policy_default_values`: values for policy assignment parameters, by the default names in
  `tenants/<tenant>/lib/alz_policy_default_values.json` (e.g. `log_analytics_workspace_id`).
- `role_assignments`: `management_group`, `role` (a built-in role name), the principal (`group` or `application`
  by display name, `user` by `mail_nickname`, or `principal_id` with `principal_type`) and an optional ABAC
  `condition`. Subscriptions below a group inherit its role assignments.

The intermediate root `mg-4esnok` is created by tier 0, with its Azure RBAC and the hierarchy settings (see
[bootstrap/Azure](../bootstrap/Azure/README.md)). Here it is `exists: true` in the architecture:
not created, but still given its archetype's policy and the role assignments on it. Tier 1's rights come from
tier 0 group `sg-prd-az-root-mgmt-t0` on the intermediate root: Contributor for the groups, Resource Policy
Contributor for policy, and Role Based Access Control Administrator for role assignments, which can't assign or
remove Owner or User Access Administrator. Plan runs have Reader there.

Moving a subscription into a group needs Owner on the subscription and write access on the group, so it is done
by the subscription's Owner (`az account management-group subscription add`), given Management Group Contributor
on the group in the config.

### Policy

Azure Policy is managed centrally, as a custom Azure Landing Zones library per tenant in `tenants/<tenant>/lib` that
`Azure/avm-ptn-alz` assigns with the hierarchy. The `azure/alz` provider loads the library even for a tenant without
`management_groups`, so every tenant has `lib/` with at least `alz_library_metadata.json`. The layout follows the
[ALZ library](https://github.com/Azure/Azure-Landing-Zones-Library):

| Path | Contents |
|---|---|
| `<architecture>.alz_architecture_definition.yaml` | The hierarchy and each group's archetypes |
| `archetype_definitions/*.alz_archetype_definition.json` | Archetypes: the policy assignments, definitions and role definitions a group gets |
| `policy_assignments/*.alz_policy_assignment.json` | Policy assignments (ARM JSON; the module sets scope and location) |
| `policy_definitions/*.alz_policy_definition.json` | Custom policy definitions (ARM JSON), created on the group of the archetype that lists them |
| `alz_policy_default_values.json` | Default names for assignment parameters, set from `policy_default_values` in the tenant config |

Tenant `4esnok_vs`:

| Assignment | Archetype (group) | What it does |
|---|---|---|
| `Deploy-AKS-Diag-LAW` | `root_4esnok` (`mg-4esnok`) | DeployIfNotExists: AKS control-plane logs (kube-apiserver, kube-audit-admin, guard, cluster-autoscaler) to the central workspace, in the resource-specific tables `AKSControlPlane` and `AKSAuditAdmin` |

| Definition | Why it is custom |
|---|---|
| `Deploy-AKS-Diag-LAW-Dedicated` | Copy of the built-in `6c66c325-74c8-42fd-a286-a74b0e2939d8` (3.0.0), which always writes to the legacy `AzureDiagnostics` table. This one sets `logAnalyticsDestinationType: Dedicated`, and a setting in `AzureDiagnostics` mode is non-compliant, so remediation switches it |

**Add a policy:**

1. Add the assignment file to `policy_assignments/`. The name is at most 24 characters, and the parameter values
   are placeholders where a default value applies. A custom definition goes in `policy_definitions/`.
2. List it in the archetype of the group it applies to. A new archetype also goes in the group's `archetypes`.
3. If a parameter takes a value from the tenant, map it in `alz_policy_default_values.json` and set it under
   `policy_default_values`.

DeployIfNotExists and Modify assignments get a system-assigned identity. The module grants it the roles from the
definition, at the group and on resources passed in parameters marked `assignPermissions`. Policy only acts on
resources created or changed after the assignment; for existing ones, create a remediation task:
`az policy remediation create --management-group <group> --policy-assignment <assignment> -n <name>`.

## Users

Each entry of the `users` section creates a cloud-only user with a `mail_nickname`, `user_principal_name` and `display_name`, and can set:

| Key | Purpose |
|---|---|
| `account_enabled` | `false` blocks sign-in (default `true`) |
| `organization` | Profile: `department`, `job_title`, `manager` (`mail_nickname`), `usage_location` (two-letter country code, needed for licences) |
| `entraid_role_names` | Permanent Entra ID directory roles |
| `password` | Initial password: `length` (default 15) and `onepassword_vault` |

Users are keyed by `mail_nickname`, and the rest of the config (group members, owners, managers, role, PIM and Conditional Access assignees) refers to them by it. Tier-0 users can't be referenced. The nickname must be unique in the tenant and never change: changing it recreates the user, with a new object ID and without its MFA registrations. Changing `user_principal_name`, e.g. to move users to another verified domain, renames the user in place.

With `password.onepassword_vault`, the password is stored in that 1Password vault and is the account's credential. Without it, the password is only in the Terraform state and must be changed at the first sign-in. Either way, the password is kept in the state.

## Applications

The `applications` section of a tenant config lists app registrations. Each entry creates the app registration and its enterprise application (service principal), and can set:

| Key | Purpose |
|---|---|
| `description` | Description of the app registration |
| `owners` | `mail_nickname` of users from `users` |
| `federated_credentials` | Workload identity federation (HCP Terraform, GitHub Actions, ...): `name`, `subject`, and `issuer` and `audiences`, which default to HCP Terraform's (`https://app.terraform.io`, `api://AzureADTokenExchange`) |
| `graph_app_roles` | Microsoft Graph application permissions, e.g. `Directory.Read.All` (admin consent is granted by the assignment) |
| `entraid_role_names` | Permanent Entra ID directory roles for the service principal |
| `client_secret` | Client secret stored in 1Password: `key_vault_name` (vault), optional `rotation_days` (default 180) and `overlap_days` (default 30) |

For a client secret, the 1Password item is titled after the application, with the client ID as username, the secret as password and the tenant and expiry in its notes. A new secret is created on the first apply after `rotation_days`; it is stored in 1Password before the old secret is deleted, so anything holding the old value must re-read it from 1Password. The secret expires `overlap_days` after its rotation date, which leaves time to run that apply. Like user passwords, the secret is also kept in the Terraform state.

Groups can list applications as `members` by display name, next to users by `mail_nickname`. The `applications` output shows each application's client ID and service principal object ID; HCP Terraform workspaces read their client IDs from the `client_ids` output, see [Workspace variables and secrets](../HCP/README.md#workspace-variables-and-secrets).
