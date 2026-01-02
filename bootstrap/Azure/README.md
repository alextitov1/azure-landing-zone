# Bootstrap Azure (EntraID) Tenant.

- create users and groups in EntraID
- assign PIM roles to groups
- create service principals

## How it works

The bootstrap process creates admin users, groups and service principals in the EntraID. These identities are used to manage azure resources and other less privileged users. Since these are the first identities created in the tenant, before any CI/CD pipelines or other automation is in place, the bootstrap process in done manually by executing a shell script.


## Prerequisites
- Terraform CLI
- 1Password + 1Password CLI and access to the organization's vault(s)
- Azure CLI
