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
organization), an optional `description` and `variables`, environment variables for every workspace in the project
(literal values only: `tfe://` references work in workspace `variables`). A
workspace variable with the same name wins; between two sets with the same variable, the set whose name sorts first
wins. Use them for values that survive a rebuild, such as the Azure tenant for dynamic credentials:
```yaml
  4esnok_vs_r1:
    variable_sets:
      - name: 4esnok_vs_r1-azure
        variables:
          TFC_AZURE_PROVIDER_AUTH: "true"
          ARM_TENANT_ID: 05af71f4-43e2-4c1a-8917-3bf5cb165cfe
```
Each workspace's Azure client IDs (`TFC_AZURE_PLAN_CLIENT_ID`, `TFC_AZURE_APPLY_CLIENT_ID`) are workspace
`variables` read from the workspace that creates its applications, see [Workspace variables](#workspace-variables).

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
| `variables` | none; environment variables, literal or read from another workspace's outputs, see below |
| `remote_state` | not shared; which workspaces may read this workspace's state, see below |
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

`remote_state` lets the runs of other workspaces read this workspace's state, for example its outputs with
`data "tfe_outputs"`. `share_with` is `organization` (every workspace), `project` (the workspaces of its project) or
`workspaces`, the workspaces of this config named in `workspaces`. Share with as few as need it:
```yaml
    remote_state:
      share_with: workspaces
      workspaces: [4esnok_vs_azure_cortex_r2]
```
`auto_destroy` makes HCP Terraform queue a destroy run for the workspace, either at a fixed time or after a period
without runs. Set exactly one of the two fields. Use it for sandbox and test workspaces only: it is refused on a
workspace with `remote_state`, because destroying it would break the workspaces that read its outputs.
```yaml
    auto_destroy:
      after_inactivity: 3d            # <number>d or <number>h after the last run
      # at: "2026-10-31T18:00:00Z"   # or a fixed RFC3339 time
```
To cancel it, remove the block. A workspace without `auto_destroy` inherits the project's auto-destroy setting, if any.

> [!WARNING]
> `auto_destroy` needs an HCP Terraform **Standard or Plus** organization. On the Free plan, HCP accepts the setting
> without an error but does not store it, so nothing is destroyed and every `hcp_tf_workspaces_r1` plan shows the same update again.

### Workspace variables

`variables` maps environment variable names to values. A value of the form `tfe://<workspace>/<output>` or
`tfe://<workspace>/<output>/<key>` is read from that workspace's output, or from the `<key>` entry of a map output;
any other value is set as it is. This is how a workspace gets the client IDs of the Entra ID applications it signs
in as, from the `client_ids` output of the workspace that creates them
(see [HCP Terraform integration](../bootstrap/Azure/README.md#hcp-terraform-integration)):
```yaml
    variables:
      TF_VAR_tenant: 4esnok_vs
      TFC_AZURE_PLAN_CLIENT_ID: tfe://4esnok_vs_azure_bootstrap_r0/client_ids/sp-hcp-entraid-mgmt-r1-plan
      TFC_AZURE_APPLY_CLIENT_ID: tfe://4esnok_vs_azure_bootstrap_r0/client_ids/sp-hcp-entraid-mgmt-r1-apply
```
`hcp_tf_workspaces_r1` reads the outputs with its own HCP token, so the source workspace doesn't need `remote_state`
for this. Sensitive outputs can't be read: put secrets in `secrets` instead.

When the workspace, output or key doesn't exist yet, for example when one merge adds both an application and the
workspace that signs in as it, the variable is left unset and the plan shows a warning instead of failing. Each
apply of a workspace that `variables` reads from re-runs `hcp_tf_workspaces_r1` (a run trigger to the top-level
`workspace` in `config.yaml`), which then sets the variable. Workspaces that run locally, such as tier 0, don't
start runs: after applying one, start a run of `hcp_tf_workspaces_r1` by hand.
