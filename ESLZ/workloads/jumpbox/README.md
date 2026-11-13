# Jumpbox

Tier-2 workload, applied by the HCP Terraform workspace `4esnok_vs_azure_jumpbox_r2`: a Windows VM,
`vm-jumpbox-dev-nzn-01` in `rg-jumpbox-dev-nzn-01`, for what only works from inside the network: the private AKS API
server, the container registry, and Azure Monitor through its private link scope.

It sits in the hub subnet `snet-shared`, not in a spoke of its own: the hub is peered with every spoke, and spokes
are not peered with each other, so only the hub reaches all of them. The hub and the spokes resolve the private DNS
zones the same way.

Configuration: `config/dev.yaml`. Terraform: `terraform/`, which calls `modules/azure-windows-jumpbox` (the Azure
Verified Module
[`avm-res-compute-virtualmachine`](https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm)).

- Windows Server 2025 Datacenter Azure Edition, `Standard_B2as_v2` (2 vCPU, 8 GiB), Trusted Launch, a 128 GiB
  Standard SSD. Azure installs its updates (patch mode `AutomaticByPlatform`).
- Public IP `pip-jumpbox-dev-nzn-01`, also its route to the internet: new subnets have no default outbound access.
- No auto-shutdown: stop it with `az vm deallocate` and start it with `az vm start`, or destroy it when idle
  ([scripts](../../../scripts/README.md)).
- The first boot installs `packages` with Chocolatey (Azure CLI, kubectl, kubelogin, Git, VS Code by default); the
  log is `C:\AzureData\bootstrap.log`.
- About $0.10 an hour while it runs (a Visual Studio subscription pays no Windows license), plus about $17 a month
  for the disk and public IP.

## What comes from the platform

The pipeline has Contributor on its resource group only, so it cannot assign roles or change the network.
Everything else is created by the platform workspaces:

| What | Created by | Read by jumpbox |
|---|---|---|
| Resource group `rg-jumpbox-dev-nzn-01`, Reader (plan) and Contributor (apply) on it | `ESLZ/governance` (`subscriptions/landingzone-jumpbox.yaml`) | name in `dev.yaml` |
| Virtual Machine Administrator Login on the resource group for `sg-az-jumpbox-admin-t1` | `ESLZ/governance` (`subscriptions/landingzone-jumpbox.yaml`) | |
| Subnet `snet-shared` in `vnet-hub-dev-nzn-01` | `ESLZ/connectivity` | `subnets` output |
| Join on `snet-shared` for the apply application (subnet `consumers`: Windows 365 Network User) | `ESLZ/connectivity` | |
| NSG `nsg-hub-shared-dev-nzn-01` and its RDP rule (`security_rules` of the subnet) | `ESLZ/connectivity` | |
| Group `sg-az-jumpbox-admin-t1` | `entraid` (tenant config) | |

## Sign in

The VM is joined to Entra ID (extension `AADLoginForWindows`). Members of `sg-az-jumpbox-admin-t1` (`entraid`,
sysadmin) have **Virtual Machine Administrator Login** on `rg-jumpbox-dev-nzn-01` from subscription vending; Owner
and Contributor alone can't sign in. Use **Virtual Machine User Login** for users without administrator rights.

1. Allow RDP from your public IP: uncomment the `security_rules` example under `snet-shared` in
   [`ESLZ/connectivity/config/network.yaml`](../../connectivity/config/network.yaml) with your address. The
   repository is public, so the address is published with it.
2. Map the host name to the public IP (the `jumpbox` output), for example a line `<public IP> jumpbox01` in
   `/etc/hosts`. Entra ID sign-in connects to the host name, not to the IP address.
3. Connect to `jumpbox01` with an RDP client that signs in with Entra ID: on Windows, Remote Desktop Connection →
   Advanced → *Use a web account to sign in to the remote computer* (`enablerdsaadauth:i:1` in an `.rdp` file).

The local administrator `azureadmin` is a fallback for clients without Entra ID sign-in. Its password is generated
into the Terraform state only; set a new one with
`az vm user update -g rg-jumpbox-dev-nzn-01 -n vm-jumpbox-dev-nzn-01 -u azureadmin -p <password>`.

A destroyed VM can leave its device `jumpbox01` in Entra ID, and a new VM with the same host name then fails to
join. Delete the stale device in Entra ID and run the workspace again, or change `computer_name`.

No Azure Bastion: the free Developer SKU can't sign in with Entra ID, and Basic is about $140 a month.

**Remove the jumpbox:** in HCP Terraform, workspace `4esnok_vs_azure_jumpbox_r2` → Settings → Destruction and
Deletion → Queue destroy plan.
