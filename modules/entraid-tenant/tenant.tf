# Tenant-wide settings. These Microsoft Graph policies exist in every tenant, so they are PATCHed
# (msgraph_update_resource): removing a setting from the YAML leaves the tenant as it is.

locals {
  domains_by_name = {
    for domain in try(var.config.domains, []) : domain.name => domain
  }

  cross_tenant_partners_by_tenant_id = {
    for partner in try(var.config.cross_tenant_access.partners, []) : partner.tenantId => partner
  }
}

# Cross-tenant access: defaults for all external tenants, and per-partner overrides (Graph property names)
resource "msgraph_update_resource" "cross_tenant_access_default" {
  count = try(var.config.cross_tenant_access.default, null) != null ? 1 : 0

  url  = "policies/crossTenantAccessPolicy/default"
  body = var.config.cross_tenant_access.default
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
