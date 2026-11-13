variable "config" {
  type        = any
  description = "The jumpbox section of ESLZ/workloads/jumpbox/config/dev.yaml; see ESLZ/workloads/jumpbox/README.md."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,15}$", var.config.computer_name)) && !can(regex("^[0-9]+$", var.config.computer_name))
    error_message = "computer_name is a Windows host name: at most 15 letters, digits and hyphens, not only digits."
  }
}

variable "name_suffix" {
  type        = list(string)
  description = "The parts of the names after the resource type, e.g. [\"jumpbox\", \"dev\", \"nzn\"]."
}

variable "instance" {
  type        = number
  description = "Instance number at the end of the names."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group of the VM, its disk, network interface and public IP."
}

variable "location" {
  type        = string
  description = "Azure region of the VM."
}

variable "subnet_id" {
  type        = string
  description = "Subnet of the VM's network interface."
}

variable "tags" {
  type        = map(string)
  description = "Tags of the VM and its resources."
  default     = null
}
