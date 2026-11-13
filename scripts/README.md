# Scripts

## hcp-destroy-paid.sh

Destroys the resources that cost money while the lab is idle, in every HCP Terraform workspace of the organization.
The rest of the lab stays in place, and the next run of each workspace creates the resources again.

The resources carry the Azure tag `cost: paid`, set with `tags:` in the stack's YAML. The same tag filters Azure Cost
Management. Tagged:

- Jumpbox: the VM, its NIC and public IP; the OS disk is deleted with the VM ([jumpbox](../ESLZ/workloads/jumpbox/README.md)).
- The private endpoint of the Azure Monitor private link scope, and Managed Grafana ([management](../ESLZ/management/README.md#cost)).
- The container registry (Premium) and the AKS cluster ([cortex](../ESLZ/workloads/cortex/README.md)); their private
  endpoint and node resource group go with them.

Not tagged, because they are billed by usage only, or cost little and other stacks depend on them:

- The Log Analytics and Azure Monitor workspaces; destroying them would also lose their data.
- The private link scope itself, which is free. VNets, NSGs and peering.
- Virtual Network Manager: its IPAM bills per active IP address, and those go away with the VMs and endpoints.
- Private DNS zones, $0.50 a month each: governance's policy role assignments and the endpoints' DNS records are on them.

### How it works

The script doesn't run `terraform destroy` locally. HCP refuses applies from the CLI on workspaces connected to VCS,
and the Azure credentials (dynamic, OIDC) only exist inside remote runs. For each workspace, the script:

1. reads the current state from HCP and takes the addresses of the managed resources with the tag. The state holds
   secrets, so it is never saved, and only addresses are printed.
2. queues a destroy run in HCP that targets them, like `terraform destroy -target=…`. Terraform also destroys
   whatever depends on them.
3. shows the plan and asks, then applies the run or discards it. The run never auto-applies, although the workspaces
   do. A run waiting for an answer blocks the workspace, so it is also discarded if the script stops.

Workspaces with local execution (the bootstraps) are skipped. The script only finds a resource once it has been
applied with its tag.

### Prerequisites

- The 1Password CLI, signed in through the desktop app, plus `jq` and `curl`.
- An HCP API token with admin rights on the workspaces, to queue destroy runs and read state and plans. By default the
  script reads the tier-0 token ([bootstrap/HCP](../bootstrap/HCP/README.md)),
  `op://IT/terraform_hcp_4esnok_tier0/credential`. Set `HCP_TOKEN_REF` to use another.

### Usage

```sh
./scripts/hcp-destroy-paid.sh --list                          # list what is tagged; no runs
./scripts/hcp-destroy-paid.sh                                 # every workspace, asking for each
./scripts/hcp-destroy-paid.sh 4esnok_vs_azure_jumpbox_r2      # only the named workspaces
./scripts/hcp-destroy-paid.sh --yes                           # without asking
```

`--tag <key>=<value>` looks for another tag instead of `cost=paid`. The script exits with 1 when a run fails, when a
state isn't processed yet, or when a named workspace doesn't exist.

### Bringing them back

The next apply of a workspace creates its resources again: **New run** in HCP, or any merge to `main` that touches the
workspace's trigger patterns.

> [!WARNING]
> The workspaces auto-apply, so merging an unrelated change to a workspace brings its resources back too. Data held
> by the destroyed resources is lost: the jumpbox's disk, the registry's images, and Grafana dashboards not kept in
> Terraform.
