variable "prefix" {
  type = string
  default = "nov"
}

# variable "environment" {
#   type = string
# }

# variable "location" {
#   type = string
# }

#### AZURE DEVOPS
variable "ENVIRONMENT" {
  type = string
}

variable "LOCATION" {
  type = string
}

# On operating systems where environment variable names are case-sensitive,
# Terraform matches the variable name exactly as given in configuration, 
# and so the required environment variable name will usually have a mix 
# of upper and lower case letters as in the above example.
#
#