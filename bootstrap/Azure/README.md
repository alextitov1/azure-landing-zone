# Entra ID tenant bootstrap (tier 0)


This directory contains the bootstrap of each Entra ID tenant: its admin and break-glass users and tier-0 groups
(`sg-t0-*`). For a tenant with Azure subscriptions, it also creates the intermediate root management group, the
Azure RBAC on it and the tenant's management group hierarchy settings (see [Intermediate root](#intermediate-root)).

It is run manually by a Global Administrator, when bootstrapping a new tenant or making fundamental changes. Users
are created with passwords stored in 1Password.

All day-two changes (other users and groups, applications, Conditional Access, management groups, ...) are done in
[tier 1](../../entraid/README.md), which references the tier-0 users under `existing_users`. Both tiers use the
shared module [`modules/entraid-tenant`](../../modules/entraid-tenant) and the same `entra_id` config schema,
described in the [tier-1 README](../../entraid/README.md#tenant-config-reference).

Each tenant is a separate Terraform root with its own HCP workspace, named in its `cloud` block, so one tenant's
config can never be planned against another tenant's state.

```
bootstrap-azure.sh         ./bootstrap-azure.sh <tenant> init|plan|apply
<tenant>/
  terraform.tf             cloud block (workspace <tenant>_entraid_bootstrap_r0), shared modules
  config.yaml              the tenant's tier-0 config
```


## Prerequisites

- Terraform CLI, Azure CLI
- 1Password CLI, with access to the `IT` vault (tokens) and the vaults that store user passwords (`password.onepassword_vault`)
- HCP: workspace `<tenant>_entraid_bootstrap_r0` in project `<tenant>_r0`, with execution mode **Local**,
  created by [HCP tier 1](../../HCP/config.yaml)


## Bootstrap a tenant

1. **Sign in** as a Global Administrator of the tenant: `az login --tenant <tenant ID> --allow-no-subscriptions`.

1. **Tenants with Azure: get rights on the tenant root group**, needed for the hierarchy settings. In the portal,
   turn on **Entra ID → Properties → Access management for Azure resources**, then sign in again with `az login`
   and assign yourself the role:
   ```sh
   az role assignment create --assignee <your object ID> --role "Hierarchy Settings Administrator" \
     --scope /providers/Microsoft.Management/managementGroups/<tenant ID>
   ```

1. **Apply tier 0.**
   ```sh
   ./bootstrap-azure.sh 4esnok_vs init
   ./bootstrap-azure.sh 4esnok_vs apply
   ```
   The plan fails if the signed-in tenant is not the config's `entraid_tenant_id`.

1. **Tenants with Azure: remove the rights again**: delete the role assignment from the previous step and turn
   **Access management for Azure resources** off.

1. **Set up the break-glass accounts**, see [Break-glass accounts](../../entraid/README.md#break-glass-accounts).

1. **Apply tier 1**, see [entraid](../../entraid/README.md#day-two-operations).

```mermaid
flowchart LR
  op[1Password<br/>tokens] --> script[./bootstrap-azure.sh &lt;tenant&gt;<br>terraform apply]
  script -- state --> t0[&lt;tenant&gt;_entraid_bootstrap_r0]
  script -- manage --> tenant[Entra ID tenant<br/>admins, break-glass, tier-0 groups]
  script -- manage --> azure[Azure<br/>intermediate root, its RBAC,<br/>hierarchy settings]
  script -- passwords --> op
```

### Add a tenant

1. Copy an existing tenant directory to `<tenant>/`. In `terraform.tf`, set the workspace name to
   `<tenant>_entraid_bootstrap_r0`. In `config.yaml`, set the tenant's `entraid_tenant_id`, admin and break-glass
   `users` and `sg-t0-*` groups. For a tenant without Azure, remove `management_groups` from `config.yaml`, and the `azapi`
   provider and resources from `terraform.tf` (as in `4esnok_mail`).
2. Add workspace `<tenant>_entraid_bootstrap_r0` in project `<tenant>_r0` to [HCP/config.yaml](../../HCP/config.yaml).
3. Bootstrap it as above, then add it to [tier 1](../../entraid/README.md#add-a-tenant).

The directory name is the tenant name, the prefix of its HCP project and workspace names. It must
match the tenant's directory in [entraid/tenants](../../entraid/tenants).


## Intermediate root

Following the Cloud Adoption Framework, a tenant's management groups hang from one intermediate root (`mg-4esnok`)
below the tenant root group, which gets no policy or role assignments itself. Tier 0 creates only that group, from
`management_groups` in the tenant config, with Azure RBAC for three groups:

| Group | Role on the intermediate root | Members |
|---|---|---|
| `sg-prd-az-root-owner-t0` | Owner | none standing; add someone only for a change that needs it |
| `sg-prd-az-root-contributor-t0` | Contributor | `sysadmin`, who runs tier 1 |
| `sg-prd-az-root-reader-t0` | Reader | none yet |

Every group and subscription below inherits these. Tier 0 also sets the tenant's hierarchy settings: new
subscriptions go to the intermediate root instead of the tenant root group, and `require_authorization_for_group_creation`
makes creating a management group require write access on its parent. These settings replace any the tenant already
has, and are removed with the intermediate root.

The groups below the intermediate root, their policy and their role assignments are in
[tier 1](../../entraid/README.md#management-groups), where the intermediate root is marked `exists: true`.


## HCP Terraform integration

The service principals that HCP Terraform runs use to sign in to Azure (OIDC dynamic credentials) are being reworked.
Until then:

- Both tiers run locally with the Azure CLI login, and HCP Terraform only stores their state.
- `applications[].federated_credentials` stays in the tier-1 configs but is not applied; the applications themselves
  are still created.
