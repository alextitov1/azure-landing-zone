# Entra ID audit and sign-in logs in Log Analytics, and an alert when a break-glass account is used.
# Driven by the `monitoring` section of the tenant YAML; kept apart from the tier-0 configuration
# because it needs an Azure subscription. Creating the Entra ID diagnostic setting needs a
# Global Administrator or Security Administrator.

locals {
  tenant_config = yamldecode(file(var.tenant_yaml_path))
  monitoring    = try(local.tenant_config.monitoring, null)

  break_glass_upns = [
    for user in local.tenant_config.users : user.user_principal_name if try(user.break_glass, false)
  ]

  # SignInLogs and the other sign-in categories need Entra ID P1; AuditLogs is free
  log_categories = try(local.monitoring.log_categories, ["AuditLogs"])
}

resource "azurerm_resource_group" "this" {
  name     = local.monitoring.resource_group_name
  location = local.monitoring.location

  lifecycle {
    precondition {
      condition     = local.monitoring != null
      error_message = "The tenant YAML has no monitoring section."
    }
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.monitoring.log_analytics_workspace_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = try(local.monitoring.retention_in_days, 90)
}

resource "azurerm_monitor_aad_diagnostic_setting" "this" {
  name                       = "entraid-to-log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = toset(local.log_categories)
    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-entraid-alerts"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "entraid"

  email_receiver {
    name                    = "admins"
    email_address           = local.monitoring.alert_email
    use_common_alert_schema = true
  }
}

# Any sign-in (SigninLogs, P1) or directory change (AuditLogs) by a break-glass account
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "break_glass" {
  count = length(local.break_glass_upns) > 0 ? 1 : 0

  name                = "break-glass-account-used"
  description         = "A break-glass (emergency access) account signed in or changed the directory"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  scopes              = [azurerm_log_analytics_workspace.this.id]
  severity            = 0
  enabled             = true

  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query                   = <<-KQL
      let accounts = dynamic(${jsonencode(local.break_glass_upns)});
      union isfuzzy=true
        (SigninLogs | where UserPrincipalName in~ (accounts) | project TimeGenerated, Account = UserPrincipalName, Activity = "Sign-in"),
        (AuditLogs | extend Account = tostring(InitiatedBy.user.userPrincipalName) | where Account in~ (accounts) | project TimeGenerated, Account, Activity = OperationName)
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }

  depends_on = [azurerm_monitor_aad_diagnostic_setting.this]
}
