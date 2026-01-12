variable "aws_ssw_region" {
  type = string
}

variable "enable_distributed_firewalling" {
  type    = bool
  default = false
}

variable "distributed_firewalling_default_action_rule_action" {
  type    = string
  default = "DENY"

}
variable "distributed_firewalling_default_action_rule_logging" {
  type    = bool
  default = false
}


variable "smarties" {
  description = "Map of smart groups to create"
  type = map(object({
    cidr = optional(string)
    tags = optional(map(string))
  }))
  default = {}
}

variable "policies" {
  description = "Map of distributed firewalling policies"
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