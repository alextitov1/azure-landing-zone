variable "config" {
  type        = any
  description = "The decoded ESLZ/connectivity/config/network.yaml; see ESLZ/connectivity/README.md."

  validation {
    condition = alltrue([
      for v in concat([var.config.hub], values(var.config.spokes)) : alltrue([
        for s in values(v.subnets) : can(tonumber(try(s.prefix_length, s)))
      ])
    ])
    error_message = "Each subnet is a prefix length, or an object with prefix_length."
  }
}
