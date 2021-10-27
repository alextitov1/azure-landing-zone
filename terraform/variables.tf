variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "australiaeast"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  default = "testing"
}

variable "admin_username" {
  description = "Username for the Domain Administrator user"
  default = "admin1"
}

variable "admin_password" {
  description = "Password for the Adminstrator user"
  default = "password1"
}