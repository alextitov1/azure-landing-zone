## Project directory structure
```sh
├── pipelines # pipeline yml files
│   └── templates # pipeline templates
└── terraform # terraform code
    ├── development # dev branch
    │   ├── launchpad # tf backend infra - level 0 (GitOps) 
    │   └── network 
    │       ├── firewall # level 1
    │       └── firewallpolicycollection # level 2
    ├── modules # terraform modules
    └── production # prod branch 
        ├── australiaeast
        ├── launchpad
        └── nznorth
```

## Terraform deployments hierarchy

```sh
┌────────────┐ # a.k.a "launchpad" manages backends (storage accounts)
│  Level 0   │ # all higher-level module exports backed config(s) from level0 
└────────────┘ # ?? can we keep level 0 statefile in git?
      ╪
┌────────────┐ # doesn't have dependable resources
│  Level 1   │ # keep state file in a storage account
└────────────┘ # pull storage account config from level 0
      ╪
┌────────────┐ # has dependencies from other modules 
│  Level n   │ # gets its state file and state files to ...
└────────────┘ # ... resolve dependencies from level 0
```