variable "name" {
}
variable "resource_group_name" {
}
variable "location" {
}
variable "sku_name" {
}
variable "sku_tier" {
}
variable "threat_intel_mode" {
}
variable "zones" {
  default = null
}
variable "ip_configurations" {
  type = any
}
variable "firewall_policy_id" {
  default = null
}

variable "dns_servers" {
  type = list(string)
  default     = null
}
variable "management_ip_configuration" {
  type = any
  default = null
}
variable "virtual_hub" {
  type = any
  default = null
}
variable "tags" {
  type  = map(string)
  default = null
}