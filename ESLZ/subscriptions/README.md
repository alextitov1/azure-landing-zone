# Subscriptions

Manages the existing subscriptions of the 4esnok.su tenant with the Azure Verified Module
[`Azure/avm-ptn-alz-sub-vending`](https://registry.terraform.io/modules/Azure/avm-ptn-alz-sub-vending/azure):
name, tags, management group, resource providers and preview features, budgets, resource groups (optionally
locked), and role assignments at subscription and resource group scope. Subscriptions are never created or
cancelled here.

Runs in the HCP Terraform workspace `4esnok_su_subscriptions` (`bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`):
a pull request shows the plan, and a merge to `main` queues a run that needs to be confirmed (`auto_apply` is off).

## Adding a subscription

1. Grant the workspace access through groups. Two groups per subscription hold the workspace's applications
   (in `bootstrap/Azure/tenants/<tenant>.yaml`), and get their roles once by hand, as the workspace cannot grant
   itself access:
   - `sg-t1-az-<name>-apps-reader` (member `sp-hcp-4esnok-su-subscriptions-t1-plan-r0`): **Reader**
   - `sg-t1-az-<name>-apps-contributor` (member `sp-hcp-4esnok-su-subscriptions-t1-apply-r0`): **Contributor**,
     and **Role Based Access Control Administrator** with a condition that blocks assigning or removing
     Owner, User Access Administrator and Role Based Access Control Administrator. The workspace can manage
     every other role assignment, but cannot make anyone, itself included, an owner.
   - for `management_group_id`, the contributor group also needs **Management Group Contributor** on the target
     management group

   Signed in with `az login` as an Owner of the subscription:
   ```sh
   sub=<subscription ID>
   name=<group name part, e.g. sub-vs>
   group_id() { az ad group show --group "$1" --query id -o tsv; }

   # Owner, User Access Administrator, Role Based Access Control Administrator
   condition=$(cat <<'EOF'
   ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))
   EOF
   )

   az role assignment create --scope /subscriptions/$sub --role Reader \
     --assignee-object-id "$(group_id sg-t1-az-$name-apps-reader)" --assignee-principal-type Group
   az role assignment create --scope /subscriptions/$sub --role Contributor \
     --assignee-object-id "$(group_id sg-t1-az-$name-apps-contributor)" --assignee-principal-type Group
   az role assignment create --scope /subscriptions/$sub --role "Role Based Access Control Administrator" \
     --assignee-object-id "$(group_id sg-t1-az-$name-apps-contributor)" --assignee-principal-type Group \
     --condition-version 2.0 --condition "$condition"
   ```
   Users get access through separate groups (`sg-t1-az-<name>-contributor`, `-reader`), whose roles are declared
   in the subscription's YAML like any other role assignment. Owner stays outside Terraform.
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
