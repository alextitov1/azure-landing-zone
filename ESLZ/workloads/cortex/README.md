# Cortex

Tier-2 workload, applied by the HCP Terraform workspace `4esnok_vs_azure_cortex_r2`. The core of the platform is an AKS
cluster, `aks-cortex-dev-nzn-01`, with its container registry `crcortexdevnzn01`, both in `rg-cortex-dev-nzn-01`.
Both are private: the API server and the registry are reached only through private endpoints in the cortex spoke.

Configuration: `config/dev.yaml`. Terraform: `terraform/` (`aks.tf`, `registry.tf`), with the Azure Verified Modules
[`avm-res-containerservice-managedcluster`](https://registry.terraform.io/modules/Azure/avm-res-containerservice-managedcluster/azurerm)
and [`avm-res-containerregistry-registry`](https://registry.terraform.io/modules/Azure/avm-res-containerregistry-registry/azurerm).

## What comes from the platform

The pipeline has Contributor on its resource group only, so it cannot assign roles or change the network.
Everything else is created by the platform workspaces:

| What | Created by | Read by cortex |
|---|---|---|
| Resource group `rg-cortex-dev-nzn-01`, Reader (plan) and Contributor (apply) on it | `ESLZ/governance` (`subscriptions/landingzone-cortex.yaml`) | name in `dev.yaml` |
| Subnets `snet-app` and `snet-aks` (AKS nodes) in `vnet-cortex-dev-nzn-01` | `ESLZ/connectivity` | `subnets` output |
| Service CIDR: IPAM static CIDR `cortex-aks-services` (/24) in the spokes pool | `ESLZ/connectivity` | `reservations` output |
| Join on `snet-app` (the registry's private endpoint) and `snet-aks` for the apply application (subnet `consumers`: Windows 365 Network User) | `ESLZ/connectivity` | |
| Private DNS zone `privatelink.azurecr.io`, linked to the hub and the spokes | `ESLZ/connectivity` | |
| The registry's DNS record in that zone: policy `Deploy-PrivateLink-DNS` adds a DNS zone group to the private endpoint | `ESLZ/governance` (`alz-lib`) | |
| Control plane identity `id-cortex-aks-dev-nzn-01`: Managed Identity Operator on the kubelet identity; consumer of `snet-aks` | `ESLZ/governance` (`managed_identities`), `ESLZ/connectivity` | name in `dev.yaml` |
| Kubelet identity `id-cortex-kubelet-dev-nzn-01`: AcrPull on the resource group | `ESLZ/governance` (`managed_identities`) | name in `dev.yaml` |
| Group `sg-az-aks-admin-t2` (cluster-admin) | `entraid` (tenant config) | object ID in `dev.yaml` |

**Merge order** for a new cluster: `ESLZ/governance` (identities), then `ESLZ/connectivity` (subnet, its
consumers, which name the control plane identity, the reservation and the private DNS zones), then the policy in
`ESLZ/governance/alz-lib` (its role assignments are on the zones), then `ESLZ/workloads/cortex`.

## Configuration

The AKS options, as in the portal's create blade, and their keys under `aks:` in `config/dev.yaml`:

| Option | Key | Value |
|---|---|---|
| **Basics** | | |
| Preset | | Dev/Test: the values below |
| Pricing tier | `sku_tier` | `Free` |
| Kubernetes version | `kubernetes_version` | `1.35` |
| Support plan | `support_plan` | `KubernetesOfficial` |
| Automatic upgrade | `auto_upgrade.channel` | `none` |
| Node security channel | `auto_upgrade.node_os_channel` | `NodeImage` |
| Maintenance window | `maintenance_window` | none (upgrades at any time) |
| Authentication and authorization | `entra` | Entra ID with Kubernetes RBAC, admin group `sg-az-aks-admin-t2`, local accounts disabled |
| **Node pools** | | |
| System pool | `system_pool` | `system`: Azure Linux, `Standard_D2ds_v5`, ephemeral OS disk, autoscale 1 to 2, `CriticalAddonsOnly` taint |
| User pools | `user_pools` | `user`: Azure Linux, `Standard_D2ds_v5`, ephemeral OS disk, autoscale 1 to 2 |
| Autoscaler profile | `autoscaler_profile` | AKS defaults |
| **Networking** | | |
| Private access | `network.private_cluster` | `true`: the API server is a private endpoint in `snet-aks` |
| Private DNS zone | `network.private_dns_zone`, `network.public_fqdn` | `none`, with the public FQDN: it resolves to the private IP, so the hub and the other spokes reach it without a DNS zone |
| Authorized IP ranges | `network.authorized_ip_ranges` | none (public API server only) |
| Container networking | | Azure CNI Overlay |
| Virtual network | | `vnet-cortex-dev-nzn-01` |
| Cluster subnet | `network.subnet` | `snet-aks` (/26, created by connectivity) |
| Kubernetes service address range | `network.service_cidr` | reserved in IPAM by connectivity |
| Kubernetes DNS service IP | `network.dns_service_ip_host` | host 10 of the service range |
| Pod address range | `network.pod_cidr` | `10.244.0.0/16` |
| DNS name prefix | `network.dns_prefix` | the cluster name, `aks-cortex-dev-nzn-01` |
| Network dataplane | `network.dataplane` | `azure` |
| Network policy engine | `network.network_policy` | `none` |
| Outbound type | `network.outbound_type` | `loadBalancer` |
| **Integrations** | | |
| Container registry | `registry` (top level) | `crcortexdevnzn01`, Premium (needed for private endpoints), Entra ID only, public access off, private endpoint `pep-crcortexdevnzn01` in `snet-app`, trusted Azure services allowed; the nodes pull with the kubelet identity |
| Azure Policy, application routing, KEDA, VPA, cost analysis | `features` | off |
| CSI drivers | `storage` | disk, file and snapshot on, blob off |
| **Monitoring** (later, into shared services) | | |
| Container logs, managed Prometheus | `monitoring.enabled` with the workspace IDs | off |
| Managed Grafana | | not on the cluster: Grafana reads the Azure Monitor workspace |
| Container network observability (ACNS) | `monitoring.network_observability` | off |
| Alerts | `monitoring.alert_email` | none |
| **Security** | | |
| Workload identity, OIDC issuer | `security.workload_identity`, `security.oidc_issuer` | on |
| Image cleaner | `security.image_cleaner` | on, every 168 hours |
| Secret store CSI driver | `security.secret_store_csi_driver` | off |
| Container network security (ACNS) | `security.network_security` | off (needs `dataplane: cilium`) |
| Run command | `security.disable_run_command` | allowed |
| Infrastructure resource group | `security.node_resource_group_lockdown` | `rg-cortex-aksnodes-dev-nzn-01`, read-only |

Some options apply at creation only (outbound type, private cluster, private DNS zone, DNS prefix); changing the
subnet or the service range replaces the cluster.

A central zone `privatelink.newzealandnorth.azmk8s.io` in `ESLZ/connectivity`, instead of `none`, is CAF's design.
AKS writes its record there and also links the zone to the spoke itself, so the control plane identity needs Private
DNS Zone Contributor on the zone and Network Contributor on the spoke VNet.

## Access

Sign in with Entra ID: `az aks get-credentials -g rg-cortex-dev-nzn-01 -n aks-cortex-dev-nzn-01`, then kubelogin.
Members of `sg-az-aks-admin-t2` are cluster-admin; give others Kubernetes roles with RoleBindings to their Entra
groups. Members of `sg-az-cortex-contributor-t2` push images to the registry.

The API server and the registry answer only inside the network:

- From the [jumpbox](../../connectivity/README.md#jumpbox) in the hub, which has the Azure CLI, kubectl and
  kubelogin: `kubectl`, `az acr login`, pushes.
- From anywhere, through Azure Resource Manager: `az aks command invoke -g rg-cortex-dev-nzn-01 -n
  aks-cortex-dev-nzn-01 --command "kubectl get pods -A"` (needs `security.disable_run_command: false`), and
  `az acr import -n crcortexdevnzn01 --source docker.io/library/nginx:latest` (needs `registry.trusted_services`).

The registry's DNS record appears a few minutes after its private endpoint, when Azure Policy has added the DNS zone
group; until then, pulls from the cluster fail.

`snet-aks` has the NSG `nsg-cortex-aks-dev-nzn-01` from connectivity, with the default rules: traffic from the
VNets and the load balancer probes is allowed. A public `LoadBalancer` service also needs an inbound rule there.

**Add a resource:** add an Azure Verified Module with `parent_id = local.resource_group_id`. Anything in the
network or with a role assignment needs a change in the platform workspaces first (see above).
