# HCP Terraform bootstrap

This directory contains the bootstrap and day-two operations code for HCP (HashiCorp Cloud Platform).

HCP Terraform is used as the backend for the Terraform state files of the deployments in this repository.

## Prerequisites

Secrets are managed in 1Password, but it is not strictly required.

## Introduction

There are two separate deployments. `hcp-tier0` is a minimal, partly click-ops setup that `hcp-tier1` depends on.
`hcp-tier1` is fully managed as code and holds the rest of the configuration.

| Tier | Workspace | Created by | Runs | Manages |
|------|-----------|------------|------|---------|
| 0 | `hcp-tier0` | Manually, in the UI | Locally, with your user token | `hcp-tier1` and its identity |
| 1 | `hcp-tier1` | Tier 0 | In HCP, on merge to `main` | All other projects and workspaces |

## Layout
```
config/organization.yaml   organization, GitHub repository, Terraform version
tier0/                     hcp-tier0, run with ./bootstrap-hcp.sh
tier1/                     hcp-tier1, run by HCP Terraform
tier1/projects/            one YAML file per project (!!update files in this directory to change projects and workspaces!!)
modules/tfe-workspace/     project and workspaces, used by both tiers
```

## Bootstrap a new HCP account

1. **Create the organization.** Register an HCP account at https://portal.cloud.hashicorp.com,
   then sign in at https://app.terraform.io and create the organization.

2. **Create the tier-0 workspace.** Create a CLI-driven workspace `hcp-tier0` and set its execution mode to **Local**.
   It is used to bootstrap the rest of the organization.

3. **Connect GitHub.** Go to **Workspaces → tier-0 → Version Control Workflow → GitHub.com**.
   - Authorize *Terraform Cloud by HashiCorp*.
   - Choose **Add another organization**.
   - Once the repository appears in the list, cancel the wizard.

4. **Create a token.** In HCP Terraform, click your avatar → **Account settings → Tokens → Create an API token**.
   Save it in 1Password as `op://IT/terraform_hcp_4esnok_tier0/credential`.

5. **Create a GitHub token.** In GitHub, go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
   Limit it to this repository and grant these repository permissions:
   Contents (read), Metadata (read), Webhooks (read and write), Commit statuses (read and write), Pull requests (read).
   Save it in 1Password as `op://IT/hcp_terraform_tier1/credential`.
   If HCP cannot create webhooks with it, use a classic token with the `repo` and `admin:repo_hook` scopes instead.

6. **Set up 1Password for tier 1.** Tier 1 reads workspace secrets from the vault `azure_t1`, so the items it passes
   to workspaces must be there. Create a 1Password service account with read and write access to that vault only,
   and save its token in the same vault as `op://azure_t1/op_hcp_rw_t1/credential`. Tier 1 uses it, and passes it
   on to `4esnok_su_entraid`, which writes the passwords it generates to that vault.

7. **Apply tier 0.**
   ```sh
   ./bootstrap-hcp.sh init
   ./bootstrap-hcp.sh apply
   ```
   This creates:
   - an API token for the built-in `owners` team, used by the pipeline
   - the `hcp` project
   - the `hcp-tier1` workspace, linked to this repository, with the token set as `TFE_TOKEN`
   - a GitHub OAuth connection, used by the pipeline workspaces that tier 1 creates
   - the 1Password service account token on `hcp-tier1`, as `OP_SERVICE_ACCOUNT_TOKEN`

8. **Check the pipeline.** Open `hcp-tier1` in the UI and check that its first run succeeds.

## Day-two operations
Projects and workspaces are defined in `tier1/projects/*.yaml`, one file per project.
To change them, edit the YAML, open a pull request, review the plan linked in the PR checks, and merge.
The merge applies the change automatically.

```yaml
project: 4esnok_su_azure
description: Azure tenant 4esnok.su
workspaces:
  4esnok_su_entraid_bootstrap:
    execution_mode: local                       # run from a laptop
  4esnok_su_subscriptions:
    vcs:                                        # run by HCP on merge to main
      working_directory: ESLZ/subscriptions
```

Optional workspace fields:

| Field | Default |
|-------|---------|
| `description` | none |
| `execution_mode` | `remote` |
| `auto_apply` | `false` |
| `terraform_version` | the value in `config/organization.yaml` |
| `tags` | none |
| `vcs.branch` | `main` |
| `vcs.trigger_patterns` | `/<working_directory>/**/*` (every file below it) |
| `env_vars` | none; environment variables set on the workspace |
| `azure_oidc` | none; Azure dynamic credentials, see below |
| `secrets` | none; sensitive environment variables from 1Password, see below |

`vcs` links the workspace to this repository through the GitHub OAuth connection created by tier 0.
`azure_oidc` sets the `TFC_AZURE_*` variables. With `from_workspace: <name>`, the tenant and client IDs are read
from the `hcp_oidc` output of that workspace; `tenant_id`, `plan_client_id` and `apply_client_id` can also be set directly.
`secrets` maps environment variable names to 1Password references, `op://<vault>/<item>/<field>`, where the field is
a built-in one (`credential`, `password`, ...) or `<section>/<field>`. Tier 1 reads them with its 1Password
service account and stores them as sensitive variables, so the vault must be `azure_t1`:
```yaml
    secrets:
      TF_VAR_onepassword_service_account_token: op://azure_t1/op_hcp_rw_t1/credential
```

## Maintenance
- **Pipeline token:** `hcp-tier1` uses this token (`TFE_TOKEN`) to manage projects and workspaces.
  It rotates every 180 days, and the old one stays valid for 30 more days.
  Run `./bootstrap-hcp.sh apply` at least every 210 days, or `hcp-tier1` loses access.
- **GitHub token:** fine-grained tokens expire after at most a year. Before that, create a new one,
  update it in 1Password and run `./bootstrap-hcp.sh apply`; the OAuth connection is updated in place.
- **GitHub access:** to change which repositories the App can see, go to
  **GitHub → Settings → Applications → Installed GitHub Apps → Terraform Cloud → Configure**.

## Tokens
Four tokens are used, each for a different identity.

The **user token** (step 4) acts as you. It is used only to run `hcp-tier0` locally.
Tier 0 needs it, because only a user token can link workspaces through the GitHub App.

The **team token** of the `owners` team is the pipeline's identity: `hcp-tier1` uses it for every HCP Terraform
API call, such as creating projects, workspaces and variables. Tier 0 creates and rotates it and stores it as
`TFE_TOKEN` on `hcp-tier1`. It is visible under **Settings → Teams → owners**.

The **GitHub token** (step 5) is not an HCP Terraform token. It lets HCP Terraform read this repository and create
webhooks for the workspaces that tier 1 links through the GitHub OAuth connection. Tier 1 cannot use the GitHub App
for that, because HCP Terraform does not allow team tokens to link workspaces through it.

The **1Password token** (step 6) belongs to the service account `op_hcp_rw_t1`, which can only access the `azure_t1` vault. Tier 1 uses it to
resolve `secrets:`. Anything in that vault can reach any workspace through a merged pull request. `azure_t1` also
holds the passwords that bootstrap/Azure generates, including the break-glass accounts, so review `secrets:` changes
carefully, and never store tier-0 credentials such as the HCP Terraform user token there.
