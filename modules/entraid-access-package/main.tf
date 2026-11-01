# Access package: grants group membership on request, with optional approval and access reviews

resource "azuread_access_package" "this" {
  catalog_id   = var.catalog_id
  display_name = var.access_package.display_name
  description  = coalesce(var.access_package.description, var.access_package.display_name)
}

resource "azuread_access_package_resource_package_association" "this" {
  for_each = toset(var.access_package.groups)

  access_package_id               = azuread_access_package.this.id
  catalog_resource_association_id = var.catalog_resource_association_ids[each.key]
  access_type                     = "Member"
}

resource "azuread_access_package_assignment_policy" "this" {
  access_package_id = azuread_access_package.this.id
  display_name      = "${var.access_package.display_name} requests"
  description       = "Managed by terraform"
  duration_in_days  = var.access_package.duration_days

  requestor_settings {
    scope_type = var.access_package.requestors
  }

  approval_settings {
    approval_required = length(var.access_package.approvers) > 0

    dynamic "approval_stage" {
      for_each = length(var.access_package.approvers) > 0 ? [var.access_package.approvers] : []
      content {
        approval_timeout_in_days = 14

        dynamic "primary_approver" {
          for_each = approval_stage.value
          content {
            object_id    = var.user_ids[primary_approver.value]
            subject_type = "singleUser"
          }
        }
      }
    }
  }

  dynamic "assignment_review_settings" {
    for_each = var.access_package.review != null ? [var.access_package.review] : []
    content {
      enabled                         = true
      review_frequency                = assignment_review_settings.value.frequency
      duration_in_days                = 14
      review_type                     = "Reviewers"
      access_review_timeout_behavior  = "removeAccess"
      access_recommendation_enabled   = true
      approver_justification_required = true

      dynamic "reviewer" {
        for_each = assignment_review_settings.value.reviewers
        content {
          object_id    = var.user_ids[reviewer.value]
          subject_type = "singleUser"
        }
      }
    }
  }
}
