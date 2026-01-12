
variable "aws_ssw_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

variable "domains" {
  description = "List of unique domain names for segmentation"
  type        = list(string)
  default     = []
}


variable "connection_policy" {
  type = list(object({
    source = string
    target = string
  }))
  default = []
}

variable "destroy_url" {
  type        = string
  description = "Dummy URL used by terracurl during destroy operations."
  default     = "https://checkip.amazonaws.com"
}
