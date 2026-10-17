# Management design

The management design area of the Cloud Adoption Framework (CAF), mapped onto this landing zone.

## Management components (CAF) to review

The management components that CAF and Azure Landing Zones (ALZ) expect, and where this repository stands on each.

| Component | What CAF expects | Status in this repo |
|---|---|---|
| Management subscription and management group | A dedicated subscription for platform management, under `Platform → Management` | Not started; `mg-platform` has no management child |
| Central Log Analytics workspace | One platform workspace, owned by the platform team | Partly done: [bootstrap/Azure/monitoring](../bootstrap/Azure/monitoring/main.tf) holds a workspace for Entra ID logs only |
| Entra ID diagnostic setting | Sign-in and audit logs in the central workspace | Done (AuditLogs; SignInLogs needs Entra ID P1) |
| Activity Log collection | `DeployIfNotExists` policy at management group scope sends every subscription's Activity Log to the workspace | Not started |
| Resource diagnostic settings | Policy-driven diagnostic settings on platform resources (firewall, VPN gateway, Key Vault, AKS, …) | Not started |
| Azure Monitor Agent and Data Collection Rules | AMA with a user-assigned managed identity; DCRs for VM Insights, Change Tracking, Defender for SQL | Not started |
| Microsoft Defender for Cloud | Plans enabled per subscription by policy, connected to the central workspace | Not started |
| Microsoft Sentinel | Optional SIEM on the central workspace | Not started |
| Alerting | Azure Monitor Baseline Alerts (AMBA), Service Health alerts, action groups | Partly done: break-glass sign-in alert and action group in `bootstrap/Azure/monitoring` |
| Update and change management | Azure Update Manager, Change Tracking through AMA | Not started |
| Backup and recovery | Recovery Services or Backup vaults, backup policy | Not started |
| Network monitoring | Network Watcher per region, VNet flow logs, Traffic Analytics | Not started |
| Retention and archive | Short interactive retention; long-term retention or immutable storage for compliance | Partly done: retention configurable, 90 days by default |
| Automation Account | Optional in current ALZ; no longer required for Update Manager or Change Tracking | Not needed |

## Log Analytics workspace

### Where it lives

- One central Log Analytics workspace in a dedicated **Management subscription**, under the `Platform → Management`
  management group. The platform team owns it; app teams don't.
- It is the destination for platform-wide logs: the Activity Log of every subscription, Entra ID sign-in and audit
  logs, diagnostic settings for platform resources (hub network, firewall, Key Vaults), Defender for Cloud and
  Sentinel.

### One workspace by default

CAF says to start with a single workspace and add more only for a clear reason:

- data residency or sovereignty (logs must stay in a region)
- separate billing or chargeback
- hard separation of who can read the data
- multi-tenant setups

App teams can still have their own workspaces for app telemetry, such as workspace-based Application Insights.
Platform and security logs stay central.

### Access model

- Use **resource-context access** ("use resource or workspace permissions"). Someone who can read a VM can then see
  that VM's logs in the shared workspace without workspace-wide rights.
- Add table-level RBAC where you need finer control.

### Collecting logs is done with Policy, not by hand

- ALZ assigns `DeployIfNotExists` policies at management group scope. They send each subscription's Activity Log to
  the workspace and set up diagnostic settings on resources. New subscriptions are covered automatically when they
  join a management group.
- For VMs, the current baseline is the **Azure Monitor Agent with Data Collection Rules** (VM Insights, Change
  Tracking, Defender for SQL) and a user-assigned managed identity. The old MMA agent is retired, and an Automation
  Account is no longer required.
- Azure Monitor Baseline Alerts (AMBA) is the companion for platform alerting.

### Retention and cost

- Keep interactive retention short (30–90 days; 90 days is included when Sentinel is enabled).
- Use long-term retention or archive, up to 12 years, for compliance. Export to an immutable storage account if you
  need tamper-proof storage.
- Watch how much data comes in. Commitment tiers only pay off from about 100 GB/day.

## How this maps to this repository

- The workspace in [bootstrap/Azure/monitoring/main.tf](../bootstrap/Azure/monitoring/main.tf) is scoped to Entra ID
  logs and the break-glass alert. In CAF terms, that is the start of the central workspace, not a separate concern.
- The CAF-aligned step is to **make it the platform Management workspace**: move it into a management subscription
  under `mg-platform` and keep the Entra diagnostic setting and break-glass alert pointing at it. Two workspaces
  (Entra and platform) would split sign-in data away from everything else that Sentinel or KQL queries would need to
  correlate.
- [workloads/cortex/config/dev.yaml](./workloads/cortex/config/dev.yaml) already expects a
  `log_analytics_workspace_id` "from the shared services outputs": the AKS Container Insights consumer this workspace
  would serve.
- Management groups are deployed with `Azure/avm-ptn-alz`. Its companion module **`Azure/avm-ptn-alz-management`**
  creates the workspace, the Data Collection Rules and the managed identity. Their IDs are then fed into the ALZ
  policy assignments through `policy_default_values`, so the Activity Log and diagnostics policies switch on across
  `mg-4esnok`.
- On a Visual Studio subscription, keep `PerGB2018`, short retention, and only the log categories you need. The first
  ~5 GB/month per billing account is free; AKS Container Insights is usually what goes past that.
- Name the workspace per the [naming convention](./README.md#naming), for example `log-mgmt-prod-aue-001`.
