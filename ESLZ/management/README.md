# Management

The central Log Analytics workspace in `newzealandnorth`, applied by the HCP Terraform workspace
`4esnok_su_management`. It is the only workspace in the landing zone: platform and workload logs both go here
([management design](../management_design.md)).

- Resource group `rg-mgmt-dev-nzn-01`.
- Workspace `log-mgmt-dev-nzn-01`: `PerGB2018`, 30 days retention, a 1 GB daily ingestion cap.
- Entra ID sign-in only: shared keys (local authentication) are off.
- Resource-context access: whoever can read a resource can read its logs here, without rights on the workspace.
- Public ingestion and query, no private link scope.

Configuration: `config/management.yaml`. Terraform: `terraform/`. Workloads read the `log_analytics_workspace_id`
output.

**Let a workload read the outputs:** add its workspace to `remote_state_consumers` of `4esnok_su_management` in
`bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`, then read them as cortex reads connectivity:

```hcl
data "tfe_outputs" "management" {
  organization = "4esnok"
  workspace    = "4esnok_su_management"
}
```

**Raise the cap:** set `log_analytics.daily_quota_gb` (`-1` removes it). Once the cap is reached, ingestion stops
until the next day (UTC).

**Remove it:** in HCP Terraform, workspace `4esnok_su_management` → Settings → Destruction and Deletion → Queue
destroy plan. The workspace is soft-deleted for 14 days, so the same name can be recovered.
