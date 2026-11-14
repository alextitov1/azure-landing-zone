# Management

The central Log Analytics workspace in `newzealandnorth`, applied by the HCP Terraform workspace
`4esnok_vs_azure_mgmt_r1`. It is the only workspace in the landing zone: platform and workload logs both go here
([management design](../management_design.md)).

- Resource group `rg-mgmt-dev-nzn-01`, created by [subscription vending](../governance/README.md#subscriptions).
- Workspace `log-mgmt-dev-nzn-01`: `PerGB2018`, 30 days retention, a 1 GB daily ingestion cap.
- Entra ID sign-in only: shared keys (local authentication) are off.
- Resource-context access: whoever can read a resource can read its logs here, without rights on the workspace.
- Ingestion only through the private link scope; queries also over the internet, so the portal and Grafana work from
  anywhere (`log_analytics.internet_ingestion_enabled`, `internet_query_enabled`).
- Managed Prometheus: Azure Monitor workspace `amw-mgmt-dev-nzn-01` (`prometheus.enabled`).
- Azure Managed Grafana `amg-mgmt-dev-aue-01` in `australiaeast`, since Grafana is not offered in `newzealandnorth`
  (`grafana.enabled`). Standard X1, Grafana 12, public endpoint. Its user-assigned identity
  `id-grafana-mgmt-dev-nzn-01` has Monitoring Reader on the subscription and Monitoring Data Reader on the resource
  group, so Prometheus, Azure Monitor metrics and Log Analytics are data sources. Users get Grafana Admin
  (`sg-az-mg4esnok-contributor-t1`) or Grafana Viewer (`sg-az-mg4esnok-reader-t1`).
- OTLP ingestion: data collection endpoint `dce-mgmt-dev-nzn-01`, data collection rule `dcr-otlp-dev-nzn-01` and
  Application Insights `appi-otlp-dev-nzn-01` (`otlp.enabled`), see [OTLP](#otlp).
- Azure Monitor private link scope `ampls-mgmt-dev-nzn-01` (`private_link.enabled`), see below.

Subscription vending (`ESLZ/governance/subscriptions/platform-management.yaml`) creates the resource group, Grafana's
identity and all the role assignments here, because this pipeline can't assign roles.

The workspace signs in as `sp-prd-az-mgmt-contributor-hcp-workspace-t2`, created by
[entraid](../../entraid/README.md). Through the group `sg-az-mgmt-contributor-t2`, it has Contributor on its resource
group and Monitoring Contributor on `mg-4esnok` ([governance](../governance/README.md)): the platform's monitoring
role reaches the resource group Azure creates for the Azure Monitor workspace's data collection endpoint, and later
diagnostic settings and data collection rules in every landing zone.

Configuration: `config/management.yaml`. Terraform: `terraform/`, which calls `modules/azure-management`. Workloads
read the `log_analytics_workspace_id`, `azure_monitor_workspace_id` and `private_link_scope_id` outputs;
`grafana_endpoint` is the Grafana URL, `otlp_endpoints` the OTLP URLs and `otlp_application_insights_id` the
Application Insights resource.

## OTLP

Azure Monitor takes OpenTelemetry signals over OTLP
([Ingest OTLP data into Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/containers/opentelemetry-protocol-ingestion)).
An application sends to the data collection endpoint; the data collection rule routes what arrives:

- Logs and traces go to the Log Analytics workspace, in its OpenTelemetry tables.
- Metrics go to the Azure Monitor workspace, so PromQL and Grafana read them. That is why `otlp` needs
  `prometheus.enabled`.
- Application Insights `appi-otlp-dev-nzn-01` (`otlp.application_insights.enabled`) stores nothing itself: the rule
  links the logs, traces and metrics to it, and its portal views (search, application map, failures) read them from
  the workspaces. It has no cost of its own; the data is billed once, as ingestion into the workspaces. Senders
  still use the OTLP URLs, not its connection string. Its views expect metrics with delta temporality.

The `otlp_endpoints` output has the URLs for the traces, logs and metrics exporters, over HTTP (`http/protobuf`).
The metrics URL contains `otlp.metrics_stream`.

Senders sign in with Entra ID, with a token for `https://monitor.azure.com/.default`. Members of
`sg-az-otlp-publisher-t2` ([entraid](../../entraid/README.md)) have Monitoring Metrics Publisher on the resource
group, where this rule is the only one. Microsoft documents the OpenTelemetry Collector with its `azure_auth`
extension as the sender; an OpenTelemetry SDK's own OTLP exporter doesn't add the token.

The endpoint is public (`otlp.public_network_access`) and also in the private link scope, so it is reached from the
internet and, privately, from the VNets. The Log Analytics workspace takes ingestion through the scope only
(`log_analytics.internet_ingestion_enabled`); if logs and traces sent over the internet don't arrive, that setting
is the first thing to check.

**Let someone send:** add the user, service principal or managed identity to `sg-az-otlp-publisher-t2` in
`entraid/tenants/4esnok_vs/config.yaml`.

## Private link

Azure Monitor keeps its private endpoints behind an Azure Monitor private link scope (AMPLS): one private endpoint
reaches every resource in the scope. Microsoft recommends a single scope on the hub of a hub-and-spoke network,
because the Azure Monitor DNS zones are shared: once a VNet resolves them privately, all of its Azure Monitor traffic
goes through that endpoint.

- In the scope: the Log Analytics workspace, the data collection endpoint that Azure created with the Azure
  Monitor workspace, through which managed Prometheus ingests, and the [OTLP](#otlp) data collection endpoint.
- Private endpoint `pep-ampls-mgmt-dev-nzn-01` in the hub subnet `snet-privatelink`
  ([connectivity](../connectivity/README.md); this workspace is a consumer of the subnet). Every VNet linked to the
  Azure Monitor private DNS zones, the hub and all spokes, reaches the scope through it.
- No DNS zone group: Azure Policy writes the records into the central zones (`Deploy-PrivateLink-DNS`), a few minutes
  after the endpoint is created.
- Access modes `Open`: the linked VNets still reach Azure Monitor resources outside the scope, over the internet.
  `PrivateOnly` blocks them.
- Prometheus queries don't go through the scope: the Azure Monitor workspace has its own private endpoint type
  (`prometheusMetrics`, zone `privatelink.<region>.prometheus.monitor.azure.com`). It isn't created, so Grafana keeps
  querying over the internet; a private-only workspace would need a Grafana managed private endpoint.
- To query the logs only from inside the network, set `log_analytics.internet_query_enabled: false`: the portal's
  Logs blade then works from the [jumpbox](../workloads/jumpbox/README.md), and Grafana's Log Analytics queries
  stop.

An AKS cluster or a VM sends through the scope once a data collection endpoint in its region is in the scope and
associated with it ([private link for Kubernetes monitoring](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-private-link)).
The endpoint of the Azure Monitor workspace is one; the [management design](../management_design.md#todo) has the
cortex steps.

## Cost

List prices in USD, October 2026 ([Azure retail prices](https://prices.azure.com/api/retail/prices)):

| Resource | Price | Idle (no cluster) | Small AKS cluster |
|---|---|---|---|
| Log Analytics | Ingestion beyond the free allowance, capped at 1 GB/day | ~$0 | a few dollars |
| Azure Monitor workspace | Free; Prometheus ingestion $0.16 per 10M samples, queries $0.001 per 10M samples; 18 months retention included | $0 | ~$14 (10k series every 30 s ≈ 860M samples) |
| Managed Grafana Standard X1 (`australiaeast`) | $0.049657/hour (~$36.25/month) + $6 per active user per month | ~$42 (1 user) | ~$42 |
| Private endpoint of the scope | $0.01/hour (~$7.30/month) + $0.01 per GB processed | ~$7 | ~$7 |
| **Total** | | **~$49/month** | **~$63/month** |

Grafana is the fixed cost and most of a Visual Studio Professional subscription's $50 monthly credit. Set
`grafana.enabled: false` to remove it when it's not in use; dashboards are lost unless exported.

**Let a workload read the outputs:** add its workspace to `remote_state.workspaces` of `4esnok_vs_azure_mgmt_r1` in
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
destroy plan. The workspace is soft-deleted for 14 days, so the same name can be recovered. Resources connected to
the private link scope can't be deleted before they leave it; the destroy plan removes them from the scope first.
