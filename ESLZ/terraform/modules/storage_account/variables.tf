variable "resource_group_name" {
  type        = string
}

variable "location" {
  type        = string
}

variable "storage_account_name" {
  type        = string
}

variable "account_kind" {
  description = "The type of storage account."
  default     = "StorageV2"
  type        = string
}

variable "skuname" {
  description = "The SKUs supported by Microsoft Azure Storage. Valid options are Premium_LRS, Premium_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS"
  default     = "Standard_RAGRS"
  type        = string
}

variable "access_tier" {
  description = "Defines the access tier for BlobStorage and StorageV2 accounts. Valid options are Hot and Cool."
  default     = "Hot"
  type        = string
}

variable "min_tls_version" {
  description = "The minimum supported TLS version for the storage account"
  default     = "TLS1_2"
  type        = string
}

variable "blob_soft_delete_retention_days" {
  description = "Specifies the number of days that the blob should be retained, between `1` and `365` days. Defaults to `7`"
  default     = 7
  type        = number
}

variable "enable_versioning" {
  description = "Is versioning enabled?"
  default     = true
  type        = bool
}

variable "public_network_access_enabled" {
  type = bool
  default = false
}

variable "shared_access_key_enabled" {
  type = bool
  default = false
}

variable "cross_tenant_replication_enabled" {
  type = bool
  default = false
}

variable "allow_nested_items_to_be_public" {
  type = bool
  default = false
}

variable "containers" {
  description = "List of Blob containers in this Storage Account."
  type = list(string)
  default = []
}

# variable "last_access_time_enabled" {
#   description = "Is the last access time based tracking enabled? Default to `false`"
#   default     = false
#   type        = bool
# }

# variable "change_feed_enabled" {
#   description = "Is the blob service properties for change feed events enabled?"
#   default     = false
#   type        = bool
# }

# variable "lifecycles" {
#   description = "Configure Azure Storage firewalls and virtual networks"
#   type        = list(object({ prefix_match = set(string), tier_to_cool_after_days = number, tier_to_archive_after_days = number, delete_after_days = number, snapshot_delete_after_days = number }))
#   default     = []
# }

# variable "managed_identity_type" {
#   description = "The type of Managed Identity which should be assigned to the Linux Virtual Machine. Possible values are `SystemAssigned`, `UserAssigned` and `SystemAssigned, UserAssigned`"
#   default     = null
#   type        = string
# }

# variable "managed_identity_ids" {
#   description = "A list of User Managed Identity ID's which should be assigned to the Linux Virtual Machine."
#   default     = null
#   type        = list(string)
# }

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}