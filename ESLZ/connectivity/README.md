# Connectivity

Lab hub-and-spoke network in `newzealandnorth`, applied by the HCP Terraform workspace `4esnok_su_connectivity`.

- Resource group `rg-connectivity-dev-nzn-01`.
- Address space `10.200.0.0/16`, allocated by Azure Virtual Network Manager IPAM: pool `ipam-hub-dev-nzn-01` (`10.200.0.0/22`) and pool `ipam-spokes-dev-nzn-01` (`10.200.16.0/20`).
- Hub `vnet-hub-dev-nzn-01` with `GatewaySubnet` (empty, reserved) and `snet-shared`.
- One VNet per spoke (`vnet-<spoke>-dev-nzn-01`), peered with the hub, with an NSG on each subnet.
- Reservations: ranges a spoke uses outside its VNet, such as the service CIDR of the cortex AKS cluster. They are
  IPAM static CIDRs in the spokes pool, so no VNet is ever allocated an overlapping range.

Configuration: `config/network.yaml`. Terraform: `terraform/`. Workloads read the `subnets` and `reservations`
outputs.

**Add a spoke:** add an entry under `spokes:` with its prefix length and subnets, and `reservations` if it needs
address space outside its VNet.

**Remove the lab:** in HCP Terraform, workspace `4esnok_su_connectivity` → Settings → Destruction and Deletion → Queue destroy plan.
