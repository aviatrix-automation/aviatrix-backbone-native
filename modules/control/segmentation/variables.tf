
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

variable "manual_transit_associations" {
  description = "Manual domain associations for transit connections. Overrides auto-inference. Map key is connection_name~gateway_name, value is domain name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for domain in values(var.manual_transit_associations) :
      contains(var.domains, domain)
    ])
    error_message = "All manual transit associations must reference domains defined in var.domains"
  }

  validation {
    condition = alltrue([
      for key in keys(var.manual_transit_associations) :
      length(split("~", key)) == 2
    ])
    error_message = "All manual_transit_associations keys must be in format 'connection_name~gateway_name' with exactly one '~' separator"
  }
}

variable "manual_spoke_associations" {
  description = "Manual domain associations for spoke gateways. Overrides auto-inference. Map key is spoke_name~transit_name, value is domain name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for domain in values(var.manual_spoke_associations) :
      contains(var.domains, domain)
    ])
    error_message = "All manual spoke associations must reference domains defined in var.domains"
  }

  validation {
    condition = alltrue([
      for key in keys(var.manual_spoke_associations) :
      length(split("~", key)) == 2
    ])
    error_message = "All manual_spoke_associations keys must be in format 'spoke_name~transit_name' with exactly one '~' separator"
  }
}

variable "exclude_connections" {
  description = "List of connection names to exclude from auto-association"
  type        = list(string)
  default     = []
}

variable "exclude_spoke_gateways" {
  description = "List of spoke gateway names to exclude from auto-association"
  type        = list(string)
  default     = []
}

variable "spoke_cloud_types" {
  description = "List of cloud types to include for spoke associations. Default is [8] for Azure only. Cloud types: 1=AWS, 8=Azure, 4=GCP, 16=OCI, 32=AliCloud"
  type        = list(number)
  default     = [8]
}
