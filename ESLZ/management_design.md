# Management design

The management design area of the Cloud Adoption Framework (CAF), mapped onto this landing zone.

## Management components (CAF) to review

The management components that CAF and Azure Landing Zones (ALZ) expect, and where this repository stands on each.

| Component | What CAF expects | Status in this repo |
|---|---|---|
| Management subscription and management group | A dedicated subscription for platform management, under `Platform → Management` | Resource group `rg-mgmt-dev-nzn-01` in the shared Visual Studio subscription; `mg-platform` has no management child |
| Central Log Analytics workspace | One platform workspace, owned by the platform team | Done: `log-mgmt-dev-nzn-01` ([ESLZ/management](./management/README.md)) |
| Entra ID diagnostic setting | Sign-in and audit logs in the central workspace | Not started (SignInLogs needs Entra ID P1; AuditLogs is free) |
| Activity Log collection | `DeployIfNotExists` policy at management group scope sends every subscription's Activity Log to the workspace | Not started |
| Resource diagnostic settings | Policy-driven diagnostic settings on platform resources (firewall, VPN gateway, Key Vault, AKS, …) | Partly done: AKS control-plane logs by policy `Deploy-AKS-Diag-LAW` on `mg-4esnok` ([Policy](../bootstrap/Azure/README.md#policy)) |
| Azure Monitor Agent and Data Collection Rules | AMA with a user-assigned managed identity; DCRs for VM Insights, Change Tracking, Defender for SQL | Not started |
| Microsoft Defender for Cloud | Plans enabled per subscription by policy, connected to the central workspace | Not started |
| Microsoft Sentinel | Optional SIEM on the central workspace | Not started |
| Alerting | Azure Monitor Baseline Alerts (AMBA), Service Health alerts, action groups | Not started |
| Update and change management | Azure Update Manager, Change Tracking through AMA | Not started |
| Backup and recovery | Recovery Services or Backup vaults, backup policy | Not started |
| Network monitoring | Network Watcher per region, VNet flow logs, Traffic Analytics | Not started |
| Retention and archive | Short interactive retention; long-term retention or immutable storage for compliance | Partly done: 30 days interactive retention, no archive |
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

- One Visual Studio subscription holds everything, so the management landing zone is a resource group,
  `rg-mgmt-dev-nzn-01`, not a subscription. It is deployed by [ESLZ/management](./management/README.md), a
  platform stack next to `ESLZ/connectivity`, with its own HCP workspace `4esnok_su_management`.
- `log-mgmt-dev-nzn-01` is the only workspace in the landing zone. The never-deployed `bootstrap/Azure/monitoring`,
  which created a second workspace for Entra ID logs, was removed.
- [workloads/cortex/config/dev.yaml](./workloads/cortex/config/dev.yaml) already expects a
  `log_analytics_workspace_id` from the shared services outputs: the AKS Container Insights consumer this workspace
  will serve (see TODO).
- Management groups are deployed with `Azure/avm-ptn-alz`. Its companion module `Azure/avm-ptn-alz-management`
  adds the Data Collection Rules and managed identity, whose IDs feed the ALZ policy assignments through
  `policy_default_values` (see TODO).
- On the Visual Studio subscription: `PerGB2018`, 30 days retention and a 1 GB daily cap. AKS Container Insights is
  usually what goes past the free allowance.

## TODO

Options to consider next, roughly in order.

- [ ] **Container Insights** (AKS node and pod logs): compare a custom DeployIfNotExists policy, since there is no
  built-in one, with the cortex Terraform switch (`monitoring.enabled`). For the Terraform route: add
  `4esnok_su_cortex` to `remote_state_consumers` of `4esnok_su_management`, read `log_analytics_workspace_id` with
  `tfe_outputs`, and give the cortex apply app the read access its Data Collection Rule needs on the workspace.
- [ ] **Azure Monitor workspace for managed Prometheus**: cortex onboards container logs and Prometheus together,
  so it needs both workspace IDs before `monitoring.enabled: true`.
- [ ] **Activity Log**: send the subscription's Activity Log to the workspace, with a diagnostic setting here or by
  policy.
- [ ] **Entra ID logs and the break-glass alert**: an Entra ID diagnostic setting to this workspace and an alert on
  any sign-in by a break-glass account. The diagnostic setting needs a Global or Security Administrator, which no
  pipeline has. The removed `bootstrap/Azure/monitoring` (git history) has the KQL for the alert.
- [ ] **Official ALZ library**: add `platform/alz` (latest `2026.10.0`) as a dependency of the custom library in
  `bootstrap/Azure/terraform/lib`, and move to ALZ's archetypes (root, platform, landing zones), so
  `DeployIfNotExists` policies deploy the Activity Log and diagnostic settings for every subscription.
- [ ] **`avm-ptn-alz-management`**: AMA Data Collection Rules (VM Insights, Change Tracking, Defender for SQL) and a
  user-assigned identity, once there are VMs.
- [ ] **Defender for Cloud**: plans per subscription, connected to the workspace.
- [ ] **Microsoft Sentinel** on the workspace.
- [ ] **Alerting**: Azure Monitor Baseline Alerts (AMBA), Service Health alerts, an action group.
- [ ] **Long-term retention or archive** for compliance; immutable storage export if logs must be tamper-proof.
- [ ] **Network monitoring**: Network Watcher, VNet flow logs and Traffic Analytics for the hub and spokes.
- [ ] **Daily cap**: revisit once real ingestion is known.
