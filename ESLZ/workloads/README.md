# Workloads

Tier-2 workloads: the applications that run in the landing zone. Each workload has its own directory, HCP
Terraform workspace and OIDC identities. Its pipeline has **Contributor on its own resource group only** (and,
where a workload needs it, the right to join its own subnet). It cannot assign roles or change the subscription,
the network or other workloads.

| Directory | HCP Terraform workspace | Resource group |
|---|---|---|
| `cortex/` | `4esnok_su_cortex` | `rg-cortex-dev-nzn-01` |
| [`alextitov1/hcp-autodestroyer`](https://github.com/alextitov1/hcp-autodestroyer) `infra/` (its own repository) | `4esnok_su_destroyer` | `rg-destroyer-dev-nzn-01` |

## Layout

```
<workload>/
├── README.md
├── config/<environment>.yaml   # what the workload owns: subscription, location, names, resource group
└── terraform/                  # working directory of the workspace
```

## Platform IDs

A workload never hardcodes IDs of resources it does not own. Platform workspaces publish them as outputs and
share their state with the workloads listed in `remote_state_consumers`
(`bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml`). The workload reads them with `data "tfe_outputs"`:

| Workspace | Outputs |
|---|---|
| `4esnok_su_connectivity` | `subnets` (`"<vnet>/<subnet>"` => ID), `reservations` (`"<spoke>/<name>"` => address prefix reserved in IPAM), `vnets`, `resource_group_id` |

## Adding a workload

| Step | File | What |
|---|---|---|
| 1 | `bootstrap/Azure/tenants/admin.4esnok.su-vs.yaml` | Applications `sp-hcp-4esnok-su-<workload>-t2-plan-r0` / `-apply-r0` (federated credentials for the workspace), user group `sg-t2-az-<workload>-contributor` |
| 2 | `bootstrap/HCP/tier1/projects/4esnok_su_azure.yaml` | Workspace `4esnok_su_<workload>`, and the workload in `remote_state_consumers` of the platform workspaces it reads |
| 3 | `ESLZ/subscriptions/config/admin-4esnok-su-vs.yaml` | Resource group `rg-<workload>-<env>-<region>-01`: Reader for the plan application, Contributor for the apply application and the user group. `managed_identities` with their role assignments, if the workload needs identities with roles (its pipeline cannot assign roles) |
| 4 | `ESLZ/connectivity/config/network.yaml` | A spoke for the workload, if it needs a network, with the apply application (and any managed identity of step 3 that must join, such as an AKS control plane) in `consumers` of each subnet it attaches NICs or private endpoints to (see `ESLZ/connectivity/README.md`), and `reservations` for ranges it uses outside the VNet |
| 5 | `ESLZ/workloads/<workload>/` | Copy `cortex/` and rename |

**Merge order.** Steps 1 and 2 can go in one merge: tier 1 runs again after the Entra ID workspace has created
the applications. Merge step 3 (and 4) after that, because role assignments and subnet consumers name the
applications. If consumers name a managed identity of step 3, merge step 4 after step 3 has applied. Merge step 5
last. Its first plan needs the resource group, its role assignments and the connectivity outputs.

Keep the applications out of `sg-t1-az-sub-vs-apps-*`. Those groups give subscription-wide rights to the
platform pipelines.
