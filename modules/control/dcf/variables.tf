variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

variable "enable_distributed_firewalling" {
  description = "Enable or disable Distributed Cloud Firewall globally."
  type        = bool
  default     = false
}

variable "distributed_firewalling_default_action_rule_action" {
  description = "Default action for traffic that does not match any policy. PERMIT or DENY."
  type        = string
  default     = "DENY"
}

variable "distributed_firewalling_default_action_rule_logging" {
  description = "Enable logging for the default action rule."
  type        = bool
  default     = false
}

variable "smarties" {
  description = "Map of smart groups to create. Each entry supports one selector type: cidr, tags, s2c, or s2c_domain."
  type = map(object({
    cidr       = optional(string)
    tags       = optional(map(string))
    s2c        = optional(list(string))
    s2c_domain = optional(string)
  }))
  default = {}
}

variable "destroy_url" {
  type        = string
  description = "Dummy URL used by terracurl during destroy operations."
  default     = "https://checkip.amazonaws.com"
}

variable "policies" {
  description = "Map of distributed firewalling policies."
  type = map(object({
    action           = string
    priority         = number
    protocol         = string
    logging          = bool
    watch            = bool
    src_smart_groups = list(string)
    dst_smart_groups = list(string)
    port_ranges      = optional(list(string), [])
  }))
  default = {}
}
