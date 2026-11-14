# ESLZ

This is a CAF-aligned Azure landing zone.

Resources are deployed with [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) (AVM) for Terraform wherever a module exists.



| Directory | Contents | HCP Terraform workspace |
|---|---|---|
| `governance/` | Management groups below `mg-4esnok`, Azure Policy, RBAC on management groups; subscription vending: subscriptions, a resource group per landing zone, role assignments | `4esnok_vs_azure_governance_r1` |
| `connectivity/` | Hub-and-spoke network, IPAM, private DNS zones | `4esnok_vs_azure_networking_r1` |
| `management/` | Central Log Analytics workspace, managed Prometheus, Managed Grafana, OTLP ingestion, Azure Monitor private link scope ([management design](./management_design.md)) | `4esnok_vs_azure_mgmt_r1` |
| `workloads/cortex/` | Tier-2 workload cortex ([workloads](./workloads/README.md)) | `4esnok_vs_azure_cortex_r2` |
| `workloads/jumpbox/` | Tier-2 workload jumpbox: a Windows VM in the hub to reach private endpoints | `4esnok_vs_azure_jumpbox_r2` |

## Naming

```
<resource-type>-<workload>-<environment>-<region>-<instance>
```

Example: `rg-connectivity-prod-nzn-001`

| Part | Description | Values |
|---|---|---|
| resource type | CAF abbreviation for the resource type | `rg` resource group, `vnet` virtual network, `snet` subnet, `nsg` network security group, `rt` route table, `peer` peering, `pip` public IP, `vgw` VPN gateway, `lgw` local network gateway, `afw` firewall, `bas` Bastion, `kv` key vault, `st` storage account, `log` Log Analytics workspace, `amw` Azure Monitor workspace, `amg` Managed Grafana, `ampls` Azure Monitor private link scope, `dce` data collection endpoint, `dcr` data collection rule, `appi` Application Insights, `pep` private endpoint, `vm` virtual machine, `nic` network interface, `osdisk` OS disk, `aks` AKS cluster, `cr` container registry (no dashes), `id` managed identity, `vnm` network manager, `ipam` IPAM pool |
| workload | Application, workload or service | `connectivity`, `hub`, `identity`, `cortex`, … |
| environment | Deployment stage | `prod`, `dev`, `qa`, `mgmt` |
| region | Short region code | `nzn` newzealandnorth, `aue` australiaeast, `ase` australiasoutheast |
| instance | Three-digit instance number | `01`, `02`, … |

A private endpoint takes the name of the resource it connects to: `pep-<resource name>`, with the network interface
`nic-pep-<resource name>`, e.g. `pep-crcortexdevnzn01`.

