# Connectivity

Lab hub-and-spoke network in `newzealandnorth`, with the central private DNS zones and a jumpbox, applied by the HCP
Terraform workspace `4esnok_vs_azure_networking_r1`.

- Resource group `rg-connectivity-dev-nzn-01`, created by [subscription vending](../governance/README.md#subscriptions).
- Address space `10.200.0.0/16`, allocated by Azure Virtual Network Manager IPAM: pool `ipam-hub-dev-nzn-01` (`10.200.0.0/22`) and pool `ipam-spokes-dev-nzn-01` (`10.200.16.0/20`).
- Hub `vnet-hub-dev-nzn-01` with `GatewaySubnet` (empty, reserved), `snet-shared` (the jumpbox) and
  `snet-privatelink` (private endpoints of platform services).
- One VNet per spoke (`vnet-<spoke>-dev-nzn-01`), peered with the hub.
- An NSG on every subnet (`nsg-<vnet>-<subnet>-dev-nzn-01`), except `GatewaySubnet`, which Azure doesn't allow one on.
- Reservations: ranges a spoke uses outside its VNet, such as the service CIDR of the cortex AKS cluster. They are
  IPAM static CIDRs in the spokes pool, so no VNet is ever allocated an overlapping range.
- Private DNS zones for private endpoints, linked to the hub and every spoke (see below).
- Jumpbox `vm-jumpbox-dev-nzn-01` in `snet-shared` (see below).

The workspace signs in as `sp-hcp-azure-networking-r1-plan` and `sp-hcp-azure-networking-r1-apply`, created by
[entraid](../../entraid/README.md). [Subscription vending](../governance/README.md#subscriptions) gives the plan
application Reader on the resource group. The apply application gets Contributor on the resource group, may assign
Windows 365 Network User there (see below), and gets Network Contributor on the subscription: the scope of the
network manager is the subscription, and Azure creates a network manager only for a caller that can write virtual
networks across its scope.

Configuration: `config/network.yaml`. Terraform: `terraform/`, which calls `modules/azure-connectivity` (network and
DNS) and `modules/azure-windows-jumpbox`. Workloads read the `subnets`, `reservations` and `private_dns_zone_ids`
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
definitions. Consumers are named as in `ESLZ/governance/subscriptions`: `group`, `user`, `service_principal`, or
`principal_id` with `principal_type`. The workspace's applications have `Directory.Read.All` to resolve the
names (`entraid/tenants/4esnok_vs/config.yaml`). Hub subnets take consumers too: `snet-privatelink` has
`sg-az-mgmt-contributor-t2`, for the [management](../management/README.md) private endpoint.

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
DNS zones" policy for it to the `Deploy-PrivateLink-DNS` initiative. The policy's managed identity gets Network
Contributor on each zone, so the zone has to exist first.

Not here yet: a DNS Private Resolver in the hub, with zones linked to the hub only. It's CAF's design once
on-premises networks or VPN clients need these names; each endpoint is $180 a month.

## Jumpbox

A Windows VM in the hub for what only works from inside the network: the private AKS API server, the container
registry, and Azure Monitor through its private link scope. The hub is peered with every spoke, and the hub and
spokes resolve the private DNS zones the same way.

- Windows Server 2025 Datacenter Azure Edition, `Standard_B2as_v2` (2 vCPU, 8 GiB), Trusted Launch, a 128 GiB
  Standard SSD. Azure installs its updates (patch mode `AutomaticByPlatform`).
- Public IP `pip-jumpbox-dev-nzn-01`, also its route to the internet: new subnets have no default outbound access.
- Shuts down every day at 19:00 New Zealand time. Start it from the portal or with `az vm start`.
- The first boot installs `packages` with Chocolatey (Azure CLI, kubectl, kubelogin, Git, VS Code by default); the
  log is `C:\AzureData\bootstrap.log`.
- About $0.10 an hour while it runs (a Visual Studio subscription pays no Windows license), plus about $17 a month
  for the disk and public IP.

**Sign in with Entra ID.** The VM is joined to Entra ID (extension `AADLoginForWindows`). Members of
`sg-az-jumpbox-admin-t1` (`entraid`, sysadmin) have **Virtual Machine Administrator Login** on
`rg-connectivity-dev-nzn-01` from subscription vending; Owner and Contributor alone can't sign in. Use **Virtual
Machine User Login** for users without administrator rights.

1. Allow RDP from your public IP: uncomment the `security_rules` example under `snet-shared` with your address.
   The repository is public, so the address is published with it.
2. Map the host name to the public IP (the `jumpbox` output), for example a line `<public IP> jumpbox01` in
   `/etc/hosts`. Entra ID sign-in connects to the host name, not to the IP address.
3. Connect to `jumpbox01` with an RDP client that signs in with Entra ID: on Windows, Remote Desktop Connection →
   Advanced → *Use a web account to sign in to the remote computer* (`enablerdsaadauth:i:1` in an `.rdp` file).

The local administrator `azureadmin` is a fallback for clients without Entra ID sign-in. Its password is generated
into the Terraform state only; set a new one with
`az vm user update -g rg-connectivity-dev-nzn-01 -n vm-jumpbox-dev-nzn-01 -u azureadmin -p <password>`.

No Azure Bastion: the free Developer SKU can't sign in with Entra ID, and Basic is about $140 a month.

**Remove the lab:** in HCP Terraform, workspace `4esnok_vs_azure_networking_r1` → Settings → Destruction and Deletion → Queue destroy plan.
