# Named locations, authentication strengths and Conditional Access policies (require Entra ID P1).
# Conditional Access cannot be used while security defaults are on (tenant_settings.security_defaults: false).

locals {
  named_locations_by_name = {
    for location in try(local.tenant_config.named_locations, []) : location.display_name => location
  }

  authentication_strengths_by_name = {
    for strength in try(local.tenant_config.authentication_strength_policies, []) : strength.display_name => strength
  }

  # Built-in authentication strengths, referenced by display name
  builtin_authentication_strength_ids = {
    "Multifactor authentication" = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000002"
    "Passwordless MFA"           = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000003"
    "Phishing-resistant MFA"     = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000004"
  }

  conditional_access_policies_by_name = {
    for policy in try(local.tenant_config.conditional_access_policies, []) : policy.display_name => policy
  }
}

resource "azuread_named_location" "this" {
  for_each     = local.named_locations_by_name
  display_name = each.key

  dynamic "ip" {
    for_each = try(each.value.ip_ranges, null) != null ? [each.value] : []
    content {
      ip_ranges = ip.value.ip_ranges
      trusted   = try(ip.value.trusted, false)
    }
  }

  dynamic "country" {
    for_each = try(each.value.countries, null) != null ? [each.value] : []
    content {
      countries_and_regions                 = country.value.countries
      include_unknown_countries_and_regions = try(country.value.include_unknown, false)
    }
  }
}

resource "azuread_authentication_strength_policy" "this" {
  for_each             = local.authentication_strengths_by_name
  display_name         = each.key
  description          = try(each.value.description, null)
  allowed_combinations = each.value.allowed_combinations # e.g. fido2, windowsHelloForBusiness, x509CertificateMultiFactor
}

module "entraid_conditional_access_policy" {
  source   = "./modules/entraid_conditional_access_policy"
  for_each = local.conditional_access_policies_by_name

  policy             = each.value
  user_ids           = { for k, v in module.entraid_user : k => v.user_id }
  group_ids          = { for k, v in module.entraid_group : k => v.group_id }
  role_template_ids  = local.role_name_to_template_id
  named_location_ids = { for k, v in azuread_named_location.this : k => v.id }
  authentication_strength_ids = merge(
    local.builtin_authentication_strength_ids,
    { for k, v in azuread_authentication_strength_policy.this : k => v.id },
  )
  always_excluded_user_ids = [for upn in local.break_glass_upns : module.entraid_user[upn].user_id]

  depends_on = [msgraph_update_resource.security_defaults]
}
