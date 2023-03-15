
variable "name" {
}

variable "firewall_policy_id" {
}

variable "priority" {
}


variable "application_rule_collection" {
  type = any
  default = null
}

variable "network_rule_collection" {
  type = any
  default = null
}

variable "nat_rule_collection" {
  type = any
  default = null
}



