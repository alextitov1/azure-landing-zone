# ESLZ

This is a CAF-aligned Azure landing zone.

Resources are deployed with [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) (AVM) for Terraform wherever a module exists.



| Directory | Contents | HCP Terraform workspace |
|---|---|---|
| `subscriptions/` | Subscriptions, resource groups, role assignments | `4esnok_su_subscriptions` |
| `connectivity/` | Hub-and-spoke network, IPAM | `4esnok_su_connectivity` |
| `management/` | Central Log Analytics workspace ([management design](./management_design.md)) | `4esnok_su_management` |
| `workloads/cortex/` | Tier-2 workload cortex ([workloads](./workloads/README.md)) | `4esnok_su_cortex` |

## Naming

```
<resource-type>-<workload>-<environment>-<region>-<instance>
```

Example: `rg-connectivity-prod-nzn-001`

| Part | Description | Values |
|---|---|---|
| resource type | CAF abbreviation for the resource type | `rg` resource group, `vnet` virtual network, `snet` subnet, `nsg` network security group, `rt` route table, `peer` peering, `pip` public IP, `vgw` VPN gateway, `lgw` local network gateway, `afw` firewall, `bas` Bastion, `kv` key vault, `st` storage account, `log` Log Analytics workspace, `vm` virtual machine, `aks` AKS cluster, `cr` container registry (no dashes), `id` managed identity, `ipam` IPAM pool |
| workload | Application, workload or service | `connectivity`, `hub`, `identity`, `cortex`, … |
| environment | Deployment stage | `prod`, `dev`, `qa`, `mgmt` |
| region | Short region code | `nzn` newzealandnorth, `aue` australiaeast, `ase` australiasoutheast |
| instance | Three-digit instance number | `01`, `02`, … |

