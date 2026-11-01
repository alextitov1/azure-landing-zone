# Connectivity

Lab hub-and-spoke network in `newzealandnorth`, applied by the HCP Terraform workspace `4esnok_vs_azure_networking_r1`.

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

**Let a workload join a subnet:** a tier-2 pipeline has Contributor on its own resource group only, so it cannot
attach NICs or private endpoints to a subnet in `rg-connectivity-dev-nzn-01`. List its apply application under
the subnet's `consumers`:

```yaml
spokes:
  cortex:
    prefix_length: 24
    subnets:
      snet-app:
        prefix_length: 26
        consumers:
          - service_principal: sp-hcp-4esnok-su-cortex-t2-apply-r0
```

Each consumer gets the built-in role **Windows 365 Network User** on that subnet only. Despite the name, it is the
narrowest built-in role with `Microsoft.Network/virtualNetworks/subnets/join/action`: it adds only read on the
VNet, the subnet and its usages. A custom role is not an option, because the workspace cannot create role
definitions. Consumers are named as in `ESLZ/subscriptions`: `group`, `user`, `service_principal`, or
`principal_id` with `principal_type`. The workspace's applications have `Directory.Read.All` to resolve the
names (`entraid/tenants/4esnok_vs/config.yaml`).

**Remove the lab:** in HCP Terraform, workspace `4esnok_vs_azure_networking_r1` → Settings → Destruction and Deletion → Queue destroy plan.
