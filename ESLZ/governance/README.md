# Governance

The management groups below the intermediate root `mg-4esnok`, with Azure Policy and Azure RBAC on them, applied
with the Azure Verified Module for Azure Landing Zones
([`Azure/avm-ptn-alz`](https://registry.terraform.io/modules/Azure/avm-ptn-alz/azurerm)) by the HCP Terraform
workspace `4esnok_vs_azure_governance_r1`. A pull request shows the plan, and a merge to `main` queues a run that
needs to be confirmed (no auto-apply): policy and role assignments here reach every subscription.

Configuration: `config/governance.yaml`. Library: `lib/`. Terraform: `terraform/`.

## Management groups

- `tenant_id`: the tenant, whose tenant root group is the parent of the hierarchy.
- `management_groups.architecture`: the hierarchy, an architecture definition in
  `lib/<architecture>.alz_architecture_definition.yaml` (management group `id`, `display_name`, `parent_id`, `null`
  for the tenant root group, `exists: true` for a group created by tier 0, and `archetypes`; the built-in `empty`
  archetype has no policies). Policy comes from archetypes in the same library (see [Policy](#policy)).
- `management_groups.location`: default location for policy managed identities.
- `management_groups.policy_default_values`: values for policy assignment parameters, by the default names in
  `lib/alz_policy_default_values.json` (e.g. `log_analytics_workspace_id`).
- `management_groups.role_assignments`: `management_group`, `role` (a built-in role name), the principal (`group` by
  display name, or `principal_id` with `principal_type`) and an optional ABAC `condition`. Subscriptions below a
  group inherit its role assignments. Groups are looked up in Entra ID, so they must exist before the plan
  ([entraid](../../entraid/README.md) creates them).

The intermediate root `mg-4esnok` is created by tier 0, with its Azure RBAC and the hierarchy settings (see
[bootstrap/Azure](../../bootstrap/Azure/README.md)). Here it is `exists: true` in the architecture: not created, but
still given its archetype's policy and the role assignments on it. Runs sign in with dynamic credentials as
`sp-hcp-azure-governance-r1-plan` and `-apply`, created by tier 0 with `Group.Read.All` to look up groups. Their
rights come from tier 0 group `sg-prd-az-root-mgmt-t0` on the intermediate root: Contributor for the groups,
Resource Policy Contributor for policy, and Role Based Access Control Administrator for role assignments, which
can't assign or remove Owner or User Access Administrator. Plan runs have Reader there.

Moving a subscription into a group needs Owner on the subscription and write access on the group, so it is done
by the subscription's Owner (`az account management-group subscription add`), given Management Group Contributor
on the group in the config.

## Policy

Azure Policy is managed centrally, as a custom Azure Landing Zones library in `lib/` that `Azure/avm-ptn-alz`
assigns with the hierarchy. The layout follows the [ALZ library](https://github.com/Azure/Azure-Landing-Zones-Library):

| Path | Contents |
|---|---|
| `<architecture>.alz_architecture_definition.yaml` | The hierarchy and each group's archetypes |
| `archetype_definitions/*.alz_archetype_definition.json` | Archetypes: the policy assignments, definitions and role definitions a group gets |
| `policy_assignments/*.alz_policy_assignment.json` | Policy assignments (ARM JSON; the module sets scope and location) |
| `policy_definitions/*.alz_policy_definition.json` | Custom policy definitions (ARM JSON), created on the group of the archetype that lists them |
| `alz_policy_default_values.json` | Default names for assignment parameters, set from `policy_default_values` in the config |

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
