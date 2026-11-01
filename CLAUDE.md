# CLAUDE.md

This is a mono-repo for a multi-cloud landing zone and other cloud resources, modelled on a mid-size organization. 
It is used to prototype and test ideas.

The cloud services are mostly trial or free tiers, so the project has caveats. For example, the HCP Terraform API tokens
have higher privileges than their names suggest, and Azure has only one subscription, so resources that belong in a
different subscription are marked by the name of their resource group.


## Rules

- This is a lab: nothing is production, even resources with production names or tags. Everything is disposable and
  redeployable, so don't write `moved`, `import` or `removed` blocks or migrate state
- Never run the 1Password CLI (`op`), and never print or log secret values. Reference secrets as `op://` in YAML;
  never write a secret value into a file.
- Don't run `terraform apply`, and don't start HCP runs, unless asked. Merging to `main` applies changes.
- Never commit to `main`: work on a branch and open a PR.
- Values go in the YAML config, not hardcoded in `.tf`. Prefer provider and HCP defaults.
- Use popular or vendor-supported terraform modules, rather than writing your own.
- Comment why, not what. No comments that restate the code or the README.
- Docs: match the existing READMEs, document behaviour rather than code, and link instead of repeating another README.
- Suggest best practices, even where the existing code doesn't follow them; the goal is to learn and improve.
- Don't change code outside the task without asking.


## Checks

```sh
terraform fmt -recursive <dir>
terraform -chdir=<dir> init -backend=false && terraform -chdir=<dir> validate
```

For `terraform test`, copy the configuration to a scratch directory. Mock providers can't mock ephemeral resources,
so stub `modules/onepassword-secrets` there.
