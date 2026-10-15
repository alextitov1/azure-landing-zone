# Connectivity

Lab hub-and-spoke network in `newzealandnorth`, applied by the HCP Terraform workspace `4esnok_su_connectivity`.

- Address space `10.200.0.0/16`, allocated by Azure Virtual Network Manager IPAM: pool `ipam-hub` (`10.200.0.0/22`) and pool `ipam-spokes` (`10.200.16.0/20`).
- Hub `vnet-hub-nzn` with `GatewaySubnet` (empty, reserved) and `snet-shared`.
- One VNet per spoke, peered with the hub, with an NSG on each subnet.

Configuration: `config/network.yaml`. Terraform: `terraform/`.

**Add a spoke:** add an entry under `spokes:` with its prefix length and subnets.

**Remove the lab:** in HCP Terraform, workspace `4esnok_su_connectivity` → Settings → Destruction and Deletion → Queue destroy plan.
