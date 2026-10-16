# Cortex

Tier-2 workload, applied by the HCP Terraform workspace `4esnok_su_cortex`. It is a placeholder for now: it
deploys nothing and only reads its resource group and subnet, which proves the pipeline's access.

- Resource group `rg-cortex-dev-nzn-01`, created by `ESLZ/subscriptions`. The pipeline gets Reader (plan) and
  Contributor (apply) on it, and the group `sg-t2-az-cortex-contributor` gets Contributor.
- Spoke `vnet-cortex-dev-nzn-01` with subnet `snet-app`, created by `ESLZ/connectivity`. The subnet ID comes
  from that workspace's `subnets` output.

Configuration: `config/dev.yaml`. Terraform: `terraform/`.

**Add a resource:** add an Azure Verified Module to `terraform/main.tf` with `parent_id = local.resource_group_id`.
To attach anything to the subnet (NICs, private endpoints), the apply application also needs
`Microsoft.Network/virtualNetworks/subnets/join/action` on `cortex/snet-app`. It does not have that yet.
