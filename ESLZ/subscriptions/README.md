# Subscriptions

Manages the existing subscriptions of the 4esnok.su tenant with the Azure Verified Module
[`Azure/avm-ptn-alz-sub-vending`](https://registry.terraform.io/modules/Azure/avm-ptn-alz-sub-vending/azure):
name, tags, management group, resource providers and preview features, budgets, resource groups (optionally
locked), user-assigned managed identities for workloads, and role assignments at subscription, resource group
and resource scope. Subscriptions are never created or cancelled here.

Runs in the HCP Terraform workspace `4esnok_su_subscriptions` (`bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`):
a pull request shows the plan, and a merge to `main` queues a run that needs to be confirmed (`auto_apply` is off).

## Adding a subscription

1. Move the subscription into management group `mg-landingzones`, signed in as an Owner of the subscription:
   ```sh
   az account management-group subscription add --name mg-landingzones --subscription <subscription ID>
   ```
   The workspace's access comes from that group (`management_groups` in `bootstrap/Azure/tenants/<tenant>.yaml`,
   applied by the tier-0 Entra ID workspace), and every subscription in it inherits:
   - `sg-t1-az-sub-vs-apps-reader` (member `sp-hcp-4esnok-su-subscriptions-t1-plan-r0`): **Reader**
   - `sg-t1-az-sub-vs-apps-contributor` (member `sp-hcp-4esnok-su-subscriptions-t1-apply-r0`): **Contributor**,
     and **Role Based Access Control Administrator** with a condition that blocks assigning or removing
     Owner, User Access Administrator and Role Based Access Control Administrator. The workspace can manage
     every other role assignment, but cannot make anyone, itself included, an owner.

   Users get access through separate groups (`sg-t1-az-sub-vs-contributor`, `-reader`), whose roles are declared
   in the subscription's YAML like any other role assignment. Owner stays outside Terraform.
2. Add `config/<name>.yaml` with at least `subscription_id`.
3. Declare what to manage.

## YAML

| Key | Purpose |
|-----|---------|
| `subscription_id` | Required, lowercase GUID |
| `location` | Default location for resource groups; default `newzealandnorth` |
| `display_name` | Renames the subscription; also required for `tags` |
| `tags` | Merged into the subscription's tags; tags removed from the YAML stay |
| `management_group_id` | Management group ID to move the subscription to |
| `resource_providers` | `{ <namespace>: [<feature>, ...] }`; registered, never unregistered |
| `budgets` | `{ <name>: { amount, start_date, end_date?, time_grain?, notifications: [{ threshold, threshold_type?, operator?, contact_emails?, contact_roles? }] } }` |
| `role_assignments` | `[{ role, <principal>, scope? }]` at subscription scope, or at the resource `scope` (ID relative to the subscription, `/resourceGroups/...`) |
| `resource_groups` | `{ <name>: { location?, tags?, lock?, role_assignments? } }` |
| `managed_identities` | `{ <name>: { resource_group, role_assignments?: [{ role, resource_group? \| scope? }] } }`: user-assigned managed identities in a resource group of this file, with their role assignments |

A role assignment names its principal by `group` (display name), `user` (user principal name),
`service_principal` (display name), or `principal_id` with `principal_type`. Names are looked up in Entra ID,
which needs `Directory.Read.All` on both applications (granted in the tenant YAML).

**Managed identities for workloads.** A workload pipeline has Contributor on its resource group and cannot
assign roles. Identities that need roles (for example the AKS control plane and kubelet identities of
`ESLZ/workloads/cortex`) are created here with their role assignments, and the workload looks them up by name.
A role assignment on a resource of another workspace (`scope`) needs that resource first: apply that workspace
before this one.

## Caveats

- **Deletes:** removing a resource group from the YAML deletes it and everything in it, unless it has `lock: true`.
  Removing a role assignment or a managed identity deletes it.
- **Existing objects are not imported:** declaring a resource group or budget that already exists fails with
  "already exists", and a role assignment created outside Terraform conflicts (`RoleAssignmentExists`, as the
  module names assignments by a GUID derived from scope, principal and role). Import it, delete it first, or
  leave it undeclared.
- **Renames outside Terraform** are not detected; the rename runs again only when `display_name` changes.
- **Telemetry** of the module is off (`enable_telemetry = false`).
