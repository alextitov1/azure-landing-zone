# Subscriptions

Manages the existing subscriptions of the 4esnok.su tenant with the Azure Verified Module
[`Azure/avm-ptn-alz-sub-vending`](https://registry.terraform.io/modules/Azure/avm-ptn-alz-sub-vending/azure):
name, tags, management group, resource providers and preview features, budgets, resource groups (optionally
locked), and role assignments at subscription and resource group scope. Subscriptions are never created or
cancelled here.

Runs in the HCP Terraform workspace `4esnok_su_subscriptions` (`bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`):
a pull request shows the plan, and a merge to `main` queues a run that needs to be confirmed (`auto_apply` is off).

## Adding a subscription

1. Grant the workspace's applications Azure RBAC on the subscription:
   - `sp-hcp-4esnok-su-subscriptions-t1-plan-r0`: **Reader**
   - `sp-hcp-4esnok-su-subscriptions-t1-apply-r0`: **Owner** (role assignments need it)
   - for `management_group_id`, also **Management Group Contributor** on the target management group
2. Add `config/<name>.yaml` with at least `subscription_id`. The plan's `subscriptions` output shows the current
   name and the resource groups that are not declared yet.
3. Declare what to manage. Existing resource groups and budgets are imported, so declaring one that exists
   does not recreate it.

## YAML

| Key | Purpose |
|-----|---------|
| `subscription_id` | Required, lowercase GUID |
| `location` | Default location for resource groups; default `australiaeast` |
| `display_name` | Renames the subscription; also required for `tags` |
| `tags` | Merged into the subscription's tags; tags removed from the YAML stay |
| `management_group_id` | Management group ID to move the subscription to |
| `resource_providers` | `{ <namespace>: [<feature>, ...] }`; registered, never unregistered |
| `budgets` | `{ <name>: { amount, start_date, end_date?, time_grain?, notifications: [{ threshold, threshold_type?, operator?, contact_emails?, contact_roles? }] } }` |
| `role_assignments` | `[{ role, <principal> }]` at subscription scope |
| `resource_groups` | `{ <name>: { location?, tags?, lock?, role_assignments? } }` |

A role assignment names its principal by `group` (display name), `user` (user principal name),
`service_principal` (display name), or `principal_id` with `principal_type`. Names are looked up in Entra ID,
which needs `Directory.Read.All` on both applications (granted in the tenant YAML).

## Caveats

- **Deletes:** removing a resource group from the YAML deletes it and everything in it, unless it has `lock: true`.
  Removing a role assignment deletes it.
- **Existing role assignments** are not imported: the module names assignments by a GUID derived from scope,
  principal and role, so one created outside Terraform conflicts (`RoleAssignmentExists`). Delete it before
  declaring it, or leave it undeclared.
- **Renames outside Terraform** are not detected; the rename runs again only when `display_name` changes.
- **Telemetry** of the module is off (`enable_telemetry = false`).
