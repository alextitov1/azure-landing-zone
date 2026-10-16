variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default = "TRFtestlab"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "australiaeast"
}

variable "admin_username" {
  description = "Username for the Domain Administrator user"
  default = "alex"
}

variable "admin_password" {
  description = "Password for the Adminstrator user"
  default = "P@$$w0rd1234!"
}