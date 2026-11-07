<!-- AI agent: do not modify this file unless explicitly requested by the user. -->
# Entra ID Day-two management

Create user, groups and applications


## tenant/config.yaml schema

`tenants/<tenant>/config.yaml`; every section of `entra_id` is optional. Users are referenced everywhere by
`mail_nickname`, groups and applications by `display_name`.

```yaml
entraid_tenant_id: <tenant ID>             # required; the plan fails when signed in to another tenant
entra_id:
  users:
    - mail_nickname: <name>                # required; the key, never change it (recreates the user)
      user_principal_name: <upn>           # required; changing it renames the user in place
      display_name: <text>                 # required
      account_enabled: true | false        # default true
      organization:                        # optional
        department: <text>
        job_title: <text>
        manager: <mail_nickname>
        usage_location: <country code>     # two letters, needed for licences
      entraid_role_names: [<role>]         # permanent directory roles, e.g. Global Administrator
      password:                            # optional
        length: <n>                        # default 15
        onepassword_vault: <vault>         # stores the password; without it, it must be changed at first sign-in

  groups:
    - display_name: <name>                 # required
      description: <text>                  # optional
      mail_nickname: <name>                # optional
      assignable_to_role: true | false     # default false
      security_enabled: true | false       # default true
      members: [<mail_nickname | application display_name | guest email>]
      dynamic_rule: <rule>                 # P1; members must then be empty
      licenses:                            # P1
        - sku: <SKU part number>           # e.g. SPB
          disabled_plans: [<plan>]
      entraid_role_names: [<role>]         # needs assignable_to_role: true

  applications:
    - display_name: <name>                 # required
      description: <text>                  # optional
      owners: [<mail_nickname>]
      graph_app_roles: [<permission>]      # Microsoft Graph application permissions, e.g. Directory.Read.All
      entraid_role_names: [<role>]         # permanent directory roles of the service principal
      federated_credentials:
        - name: <name>                     # required
          subject: <subject>               # required, e.g. organization:<org>:project:<project>:workspace:<ws>:run_phase:<plan|apply>
          issuer: <url>                    # default https://app.terraform.io
          audiences: [<audience>]          # default [api://AzureADTokenExchange]
          description: <text>              # optional
      client_secret:                       # optional; stored in 1Password
        key_vault_name: <vault>            # required
        rotation_days: <n>                 # default 180
        overlap_days: <n>                  # default 30

  named_locations:                         # P1
    - display_name: <name>
      ip_ranges: [<cidr>]                  # either ip_ranges ...
      trusted: true | false                # default false
      countries: [<country code>]          # ... or countries
      include_unknown: true | false        # default false

  authentication_strength_policies:        # P1
    - display_name: <name>
      description: <text>
      allowed_combinations: [<method>]     # e.g. fido2

  conditional_access_policies:             # P1
    - display_name: <name>
      state: enabled | disabled | enabledForReportingButNotEnforced  # default report-only
      users:
        include: [<mail_nickname> | All | None | GuestsOrExternalUsers]
        exclude: [<mail_nickname>]
        include_groups: [<group>]
        exclude_groups: [<group>]
        include_roles: [<role>]
        exclude_roles: [<role>]
      applications:
        include: [<application ID> | All | None | Office365 | MicrosoftAdminPortals]  # default [All]
        exclude: [<application ID>]
      client_app_types: [all | browser | mobileAppsAndDesktopClients | exchangeActiveSync | other]  # default [all]
      locations:
        include: [<named location> | All | AllTrusted]
        exclude: [<named location>]
      grant:
        operator: OR | AND                 # default OR
        controls: [block | mfa | compliantDevice | domainJoinedDevice | passwordChange]
        authentication_strength: <name>    # built-in or from authentication_strength_policies

  pim_roles:                               # P2
    - role_name: <role>
      assignment_type: User | Group | ServicePrincipal
      assignee_name: <mail_nickname | group | application>
      duration: <ISO 8601>                 # maximum activation time of the role, e.g. PT8H

  access_package_catalogs:                 # P2 or ID Governance
    - display_name: <name>
      description: <text>
  access_packages:
    - display_name: <name>
      description: <text>
      catalog: <catalog display_name>      # required
      groups: [<group>]                    # memberships the package grants
      requestors: <scope>                  # default AllExistingDirectoryMemberUsers
      approvers: [<mail_nickname>]         # empty: no approval
      duration_days: <n>                   # default 90
      review:
        frequency: weekly | monthly | quarterly | halfyearly | annual  # default quarterly
        reviewers: [<mail_nickname>]

  administrative_units:
    - display_name: <name>
      description: <text>
      members: [<mail_nickname | group>]
      role_assignments:                    # unit admins need P1
        - role_name: <role>
          assignee: <mail_nickname | group>

  guests:
    - email: <address>                     # the key; groups list guests by it
      display_name: <text>
      redirect_url: <url>                  # default https://myapps.microsoft.com

  cross_tenant_access:                     # Microsoft Graph property names
    default: { <property>: <value> }       # updated in place; removing it leaves the tenant as it is
    partners:
      - tenantId: <tenant ID>
        <property>: <value>                # e.g. inboundTrust: { isMfaAccepted: true }

  domains:
    - name: <domain>
      verify: true | false                 # set true once the TXT record from domain_verification_records is published
```

