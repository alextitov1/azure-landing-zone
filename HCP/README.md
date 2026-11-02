# HCP Terraform: projects and workspaces (tier 1)

The workspace `hcp_tf_workspaces_r1` (project `hcp_tf_r1`) runs this directory in HCP Terraform on merge to `main`
and manages every other HCP Terraform project and workspace. It is created by tier 0, see
[bootstrap/HCP](../bootstrap/HCP/README.md).

```
config.yaml    organization and all projects and workspaces (repository per workspace in vcs.repo)
terraform.tf   reads config.yaml; uses ../modules/hcp-projects (shared with tier 0)
```

## Day-two operations
Projects and workspaces are defined under `projects:` in `config.yaml`, keyed by project name.
To change them, edit the file, open a pull request, review the plan linked in the PR checks, and merge.
The merge applies the change automatically.

```yaml
projects:
  4esnok_vs_r0:                                   # project name
    description: "Azure tenant 4esnok.su: bootstrap"
    workspaces:
      4esnok_vs_entraid_bootstrap_r0:
        execution_mode: local                     # run from a laptop
      4esnok_vs_azure_bootstrap_r0:
        vcs:                                      # run by HCP on merge to main
          repo: alextitov1/azure-landing-zone     # required
          github_app_installation: alextitov1     # required
          working_directory: ESLZ/subscriptions
```

Optional project field `variable_sets`: variable sets attached to the project, each with a `name` (unique in the
organization), an optional `description` and `env_vars`, environment variables for every workspace in the project. A
workspace variable with the same name wins; between two sets with the same variable, the set whose name sorts first
wins. Use them for values that survive a rebuild, such as the Azure tenant for dynamic credentials:
```yaml
  4esnok_vs_r1:
    variable_sets:
      - name: 4esnok_vs_r1-azure
        env_vars:
          TFC_AZURE_PROVIDER_AUTH: "true"
          ARM_TENANT_ID: 05af71f4-43e2-4c1a-8917-3bf5cb165cfe
```
Each workspace's Azure client IDs (`TFC_AZURE_PLAN_CLIENT_ID`, `TFC_AZURE_APPLY_CLIENT_ID`) are not set here: the tier
that creates its identities writes them, see [HCP Terraform integration](../bootstrap/Azure/README.md#hcp-terraform-integration).

Optional workspace fields:

| Field | Default |
|-------|---------|
| `description` | none |
| `execution_mode` | `remote` |
| `auto_apply` | `false`; applies to API, UI and VCS runs and to runs started by run triggers |
| `terraform_version` | HCP's default (latest) for new workspaces; existing workspaces keep their version |
| `tags` | none |
| `vcs.branch` | `main` |
| `vcs.trigger_patterns` | `/<working_directory>/**/*` (every file below it) |
| `env_vars` | none; environment variables set on the workspace |
| `remote_state_consumers` | none; workspaces, in any project, that may read this workspace's outputs |
| `secrets` | none; sensitive environment variables from 1Password, see below |
| `auto_destroy` | none; scheduled destroy run, see below |

`vcs` links the workspace to `vcs.repo` (required) through the GitHub App installation named in
`vcs.github_app_installation` (required, the GitHub account or organization). The App must have access to the repository:
**GitHub → Settings → Applications → Installed GitHub Apps → Terraform Cloud → Configure**.
`secrets` maps environment variable names to 1Password references, `op://<vault>/<item>/<field>`, where the field is
a built-in one (`credential`, `password`, ...) or `<section>/<field>`. Tier 1 reads them with its 1Password
service account and stores them as sensitive variables, so the vault must be `azure_t1`:
```yaml
    secrets:
      TF_VAR_onepassword_service_account_token: op://azure_t1/op_hcp_rw_t1/credential
```
`auto_destroy` makes HCP Terraform queue a destroy run for the workspace, either at a fixed time or after a period
without runs. Set exactly one of the two fields. Use it for sandbox and test workspaces only: it is refused on a
workspace with `remote_state_consumers`, because destroying it would break the workspaces that read its outputs.
```yaml
    auto_destroy:
      after_inactivity: 3d            # <number>d or <number>h after the last run
      # at: "2026-10-31T18:00:00Z"   # or a fixed RFC3339 time
```
To cancel it, remove the block. A workspace without `auto_destroy` inherits the project's auto-destroy setting, if any.

> [!WARNING]
> `auto_destroy` needs an HCP Terraform **Standard or Plus** organization. On the Free plan, HCP accepts the setting
> without an error but does not store it, so nothing is destroyed and every `hcp_tf_workspaces_r1` plan shows the same update again.

