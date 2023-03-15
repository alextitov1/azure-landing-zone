
variable "name" {
}

variable "resource_group_name" {
}

variable "location" {
}

variable "sku" {
}

variable "threat_intelligence_mode" {
  default = "Alert"
}

variable "base_policy_id" { 
  default = null
}

variable "dns" {
  type = any
  default = null
}

variable "threat_intelligence_allowlist" {
  type = any
  default = null
}

variable "tags" {
  type        = map(string)
  default = null
}

variable "identity" {
  type = any
  default = null
}

variable "tls_certificate" {
  type = any
  default = null
}

variable "intrusion_detection" {
  type = any
  default = null
}

variable "insights" {
  type = any
  default = null
}

variable "explicit_proxy" {
  type = any
  default = null
}


