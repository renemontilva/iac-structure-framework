variable "region" {
    type = string
    description = "The AWS region to deploy to."
  
}
variable "network" {
  type        = any
  description = "Network configuration for the VPC."
}
