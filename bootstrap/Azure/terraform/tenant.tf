# Tenant-wide settings. These Microsoft Graph policies exist in every tenant, so they are PATCHed
# (msgraph_update_resource): removing a setting from the YAML leaves the tenant as it is.

locals {
  tenant_settings = try(local.tenant_config.tenant_settings, {})

  # Remote runs sign in with the workspace's dynamic credentials; local runs use the Azure CLI login
  remote_run = var.tfc_azure_dynamic_credentials != null

  domains_by_name = {
    for domain in try(local.tenant_config.domains, []) : domain.name => domain
  }

  cross_tenant_partners_by_tenant_id = {
    for partner in try(local.tenant_config.cross_tenant_access.partners, []) : partner.tenantId => partner
  }
}

# Default user and guest permissions, e.g. who can register apps, create tenants or invite guests.
# The body uses Graph property names: https://learn.microsoft.com/graph/api/resources/authorizationpolicy
resource "msgraph_update_resource" "authorization_policy" {
  count = try(local.tenant_settings.authorization_policy, null) != null ? 1 : 0

  url  = "policies/authorizationPolicy"
  body = local.tenant_settings.authorization_policy
}

# Security defaults: free baseline MFA. Must be off before Conditional Access policies can be created.
# Needs Policy.ReadWrite.ConditionalAccess, which Azure CLI tokens never carry, so it is applied only
# in remote runs (OIDC as the tier-0 apply application). New tenants have security defaults on.
resource "msgraph_update_resource" "security_defaults" {
  count = try(local.tenant_settings.security_defaults, null) != null && local.remote_run ? 1 : 0

  url = "policies/identitySecurityDefaultsEnforcementPolicy"
  body = {
    isEnabled = local.tenant_settings.security_defaults
  }
}

# Cross-tenant access: defaults for all external tenants, and per-partner overrides (Graph property names)
resource "msgraph_update_resource" "cross_tenant_access_default" {
  count = try(local.tenant_config.cross_tenant_access.default, null) != null ? 1 : 0

  url  = "policies/crossTenantAccessPolicy/default"
  body = local.tenant_config.cross_tenant_access.default
}

resource "msgraph_resource" "cross_tenant_partner" {
  for_each = local.cross_tenant_partners_by_tenant_id

  url  = "policies/crossTenantAccessPolicy/partners"
  body = each.value
}

# Custom domains: added unverified; publish the TXT record from the domain_verification_records
# output in DNS, then set `verify: true` to verify the domain.
resource "msgraph_resource" "domain" {
  for_each = local.domains_by_name

  url = "domains"
  body = {
    id = each.key
  }
  response_export_values = {
    is_verified = "isVerified"
  }
}

data "msgraph_resource" "domain_verification_records" {
  for_each = local.domains_by_name

  url = "domains/${msgraph_resource.domain[each.key].id}/verificationDnsRecords"
  response_export_values = {
    records = "value[].{type: recordType, label: label, text: text, ttl: ttl}"
  }
}

resource "msgraph_resource_action" "domain_verify" {
  for_each = { for name, domain in local.domains_by_name : name => domain if try(domain.verify, false) }

  resource_url = "domains/${msgraph_resource.domain[each.key].id}"
  action       = "verify"
  method       = "POST"
}

# The tenant's custom domain from the YAML must already be verified
data "azuread_domains" "all" {}

check "local_run_skips_security_defaults" {
  assert {
    condition     = local.remote_run || try(local.tenant_settings.security_defaults, null) == null
    error_message = "security_defaults is not applied in local runs (the Azure CLI token lacks Policy.ReadWrite.ConditionalAccess). It is applied by the next remote run."
  }
}
