# Management

The central Log Analytics workspace in `newzealandnorth`, applied by the HCP Terraform workspace
`4esnok_vs_azure_mgmt_r1`. It is the only workspace in the landing zone: platform and workload logs both go here
([management design](../management_design.md)).

- Resource group `rg-mgmt-dev-nzn-01`.
- Workspace `log-mgmt-dev-nzn-01`: `PerGB2018`, 30 days retention, a 1 GB daily ingestion cap.
- Entra ID sign-in only: shared keys (local authentication) are off.
- Resource-context access: whoever can read a resource can read its logs here, without rights on the workspace.
- Public ingestion and query, no private link scope.
- Managed Prometheus: Azure Monitor workspace `amw-mgmt-dev-nzn-01` (`prometheus.enabled`).
- Azure Managed Grafana `amg-mgmt-dev-aue-01` in `australiaeast`, since Grafana is not offered in `newzealandnorth`
  (`grafana.enabled`). Standard X1, Grafana 12, public endpoint. Its managed identity has Monitoring Data Reader on
  the Prometheus workspace and Monitoring Reader on the subscription, so Prometheus, Azure Monitor metrics and
  Log Analytics are data sources. Users get Grafana Admin (`sg-t1-az-sub-vs-contributor`) or Grafana Viewer
  (`sg-t1-az-sub-vs-reader`) from `ESLZ/subscriptions`, which also registers `Microsoft.Dashboard`.

Configuration: `config/management.yaml`. Terraform: `terraform/`. Workloads read the `log_analytics_workspace_id`
and `azure_monitor_workspace_id` outputs; `grafana_endpoint` is the Grafana URL.

## Cost

List prices in USD, October 2026 ([Azure retail prices](https://prices.azure.com/api/retail/prices)):

| Resource | Price | Idle (no cluster) | Small AKS cluster |
|---|---|---|---|
| Log Analytics | Ingestion beyond the free allowance, capped at 1 GB/day | ~$0 | a few dollars |
| Azure Monitor workspace | Free; Prometheus ingestion $0.16 per 10M samples, queries $0.001 per 10M samples; 18 months retention included | $0 | ~$14 (10k series every 30 s ≈ 860M samples) |
| Managed Grafana Standard X1 (`australiaeast`) | $0.049657/hour (~$36.25/month) + $6 per active user per month | ~$42 (1 user) | ~$42 |
| **Total** | | **~$42/month** | **~$56/month** |

Grafana is the fixed cost and most of a Visual Studio Professional subscription's $50 monthly credit. Set
`grafana.enabled: false` to remove it when it's not in use; dashboards are lost unless exported.

**Let a workload read the outputs:** add its workspace to `remote_state_consumers` of `4esnok_vs_azure_mgmt_r1` in
`HCP/config.yaml`, then read them as cortex reads connectivity:

```hcl
data "tfe_outputs" "management" {
  organization = "4esnok"
  workspace    = "4esnok_vs_azure_mgmt_r1"
}
```

**Raise the cap:** set `log_analytics.daily_quota_gb` (`-1` removes it). Once the cap is reached, ingestion stops
until the next day (UTC).

**Remove it:** in HCP Terraform, workspace `4esnok_vs_azure_mgmt_r1` → Settings → Destruction and Deletion → Queue
destroy plan. The workspace is soft-deleted for 14 days, so the same name can be recovered.
