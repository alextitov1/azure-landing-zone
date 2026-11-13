# Connectivity

Lab hub-and-spoke network in `newzealandnorth`, with the central private DNS zones, applied by the HCP Terraform
workspace `4esnok_vs_azure_networking_r1`.

- Resource group `rg-connectivity-dev-nzn-01`, created by [subscription vending](../governance/README.md#subscriptions).
- Address space `10.200.0.0/16`, allocated by Azure Virtual Network Manager IPAM: pool `ipam-hub-dev-nzn-01` (`10.200.0.0/22`) and pool `ipam-spokes-dev-nzn-01` (`10.200.16.0/20`).
- Hub `vnet-hub-dev-nzn-01` with `GatewaySubnet` (empty, reserved), `snet-shared` (shared services: the
  [jumpbox](../workloads/jumpbox/README.md) workload joins it) and `snet-privatelink` (private endpoints of platform
  services).
- One VNet per spoke (`vnet-<spoke>-dev-nzn-01`), peered with the hub.
- An NSG on every subnet (`nsg-<vnet>-<subnet>-dev-nzn-01`), except `GatewaySubnet`, which Azure doesn't allow one on.
- Reservations: ranges a spoke uses outside its VNet, such as the service CIDR of the cortex AKS cluster. They are
  IPAM static CIDRs in the spokes pool, so no VNet is ever allocated an overlapping range.
- Private DNS zones for private endpoints, linked to the hub and every spoke (see below).

The workspace signs in as `sp-hcp-azure-networking-r1-plan` and `sp-hcp-azure-networking-r1-apply`, created by
[entraid](../../entraid/README.md). [Subscription vending](../governance/README.md#subscriptions) gives the plan
application Reader on the resource group. The apply application gets Contributor on the resource group, may assign
Windows 365 Network User there (see below), and gets Network Contributor on the subscription: the scope of the
network manager is the subscription, and Azure creates a network manager only for a caller that can write virtual
networks across its scope.

Configuration: `config/network.yaml`. Terraform: `terraform/`, which calls `modules/azure-connectivity`. Workloads
read the `subnets`, `reservations` and `private_dns_zone_ids` outputs.

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
definitions. Consumers are named as in `ESLZ/governance/subscriptions`: `group`, `user`, `service_principal`, or
`principal_id` with `principal_type`. The workspace's applications have `Directory.Read.All` to resolve the
names (`entraid/tenants/4esnok_vs/config.yaml`). Hub subnets take consumers too: `snet-privatelink` has
`sg-az-mgmt-contributor-t2`, for the [management](../management/README.md) private endpoint, and `snet-shared` has
the apply application of the [jumpbox](../workloads/jumpbox/README.md).

**Open a port:** add `security_rules` to the subnet, with the attribute names of `azurerm_network_security_rule`.
Without rules, the NSG has only Azure's defaults: traffic within and between the VNets and from the load balancer
is allowed, inbound traffic from the internet is denied.

## Private DNS zones

CAF's model for private endpoints: one central zone per service, owned by connectivity, and Azure Policy writes the
records.

- `private_dns_zones` in the config lists the zones: Container Registry and the five zones of the Azure Monitor
  private link scope. Each is linked to the hub and every spoke, which use Azure DNS, so they resolve private
  endpoints without a DNS server of their own.
- A pipeline creates its private endpoint without a DNS zone group. The policy `Deploy-PrivateLink-DNS`
  (`ESLZ/governance/alz-lib`, on `mg-landingzones`) adds one, which writes the A record into the central zone, a few
  minutes after the endpoint is created. Pipelines need no rights on the zones.
- Only the zones in use are created, $0.50 a month each: the ALZ initiative `Deploy-Private-DNS-Zones` needs all of
  its 53 zones to exist, about $15 a month. `Deploy-PrivateLink-DNS` uses the same built-in policies for the services
  here.

**Add a service:** add its zone to `private_dns_zones` and apply; then add the built-in "Configure ... to use private
DNS zones" policy for it to the `Deploy-PrivateLink-DNS` initiative, and its zone parameters to
`policy_assign_permissions_unset` in `ESLZ/governance/config.yaml`. The policy's managed identity has Private DNS Zone
Contributor on the resource group, not on each zone, so either workspace can be applied or destroyed first. A private
endpoint created while its zone is missing gets no record until the policy is remediated.

Not here yet: a DNS Private Resolver in the hub, with zones linked to the hub only. It's CAF's design once
on-premises networks or VPN clients need these names; each endpoint is $180 a month.

**Remove the lab:** in HCP Terraform, workspace `4esnok_vs_azure_networking_r1` → Settings → Destruction and Deletion → Queue destroy plan.
