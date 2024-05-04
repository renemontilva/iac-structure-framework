variable "region" {
  type        = string
  description = "The AWS region to deploy to."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to all resources."
}

