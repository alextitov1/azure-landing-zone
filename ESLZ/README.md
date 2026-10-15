# ESLZ

| Directory | Contents | HCP Terraform workspace |
|---|---|---|
| `subscriptions/` | Subscriptions, resource groups, role assignments | `4esnok_su_subscriptions` |
| `connectivity/` | Hub-and-spoke network, IPAM | `4esnok_su_connectivity` |

## Naming

`<type>-<workload>-<env>-<region>-<nn>`, lowercase, e.g. `rg-connectivity-dev-nzn-01`. Types follow the Cloud Adoption Framework abbreviations.

| Part | Values |
|---|---|
| type | `rg` resource group, `vnm` network manager, `ipam` IPAM pool, `vnet` virtual network, `snet` subnet, `nsg` network security group, `rt` route table, `peer` peering, `pip` public IP, `vgw` VPN gateway, `lgw` local network gateway, `afw` firewall, `bas` Bastion, `kv` key vault, `st` storage account, `log` Log Analytics workspace, `vm` virtual machine |
| workload | `connectivity`, `hub`, `workload`, … |
| env | `dev`, `tst`, `prd` |
| region | `nzn` newzealandnorth, `aue` australiaeast, `ase` australiasoutheast |
| nn | `01`, `02`, … |

Exceptions:
- Child resources take only type and purpose: subnets `snet-<purpose>`, peerings `peer-<from>-to-<to>`.
- Names fixed by Azure stay as they are: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureBastionSubnet`.
- Storage accounts have no hyphens: `st<workload><env><region><nn>`.
