locals {
  smart_groups_map         = { for sg in data.aviatrix_smart_groups.foo.smart_groups : sg.name => sg.uuid }
  created_smart_groups_map = { for name, sg in aviatrix_smart_group.smarties : name => sg.uuid }
}

resource "aviatrix_distributed_firewalling_config" "enable_distributed_firewalling" {
  enable_distributed_firewalling = var.enable_distributed_firewalling
}

resource "aviatrix_distributed_firewalling_default_action_rule" "distributed_firewalling_default_action_rule" {
  action  = var.distributed_firewalling_default_action_rule_action
  logging = var.distributed_firewalling_default_action_rule_logging
}

resource "aviatrix_smart_group" "smarties" {
  for_each = var.smarties
  name     = each.key
  dynamic "selector" {
    for_each = contains(keys(each.value), "cidr") ? [1] : []
    content {
      match_expressions {
        cidr = each.value.cidr
      }
    }
  }
  dynamic "selector" {
    for_each = contains(keys(each.value), "cidr") ? [] : [1]
    content {
      match_expressions {
        type = "vm"
        tags = each.value.tags
      }
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "policies" {
  dynamic "policies" {
    for_each = var.policies
    content {
      name             = policies.key
      action           = policies.value.action
      priority         = policies.value.priority
      protocol         = policies.value.protocol
      logging          = policies.value.logging
      watch            = policies.value.watch
      src_smart_groups = [for sg_name in policies.value.src_smart_groups : contains(keys(local.created_smart_groups_map), sg_name) ? local.created_smart_groups_map[sg_name] : local.smart_groups_map[sg_name]]
      dst_smart_groups = [for sg_name in policies.value.dst_smart_groups : contains(keys(local.created_smart_groups_map), sg_name) ? local.created_smart_groups_map[sg_name] : local.smart_groups_map[sg_name]]
      dynamic "port_ranges" {
        for_each = (policies.value.protocol != "icmp" && length(lookup(policies.value, "port_ranges", [])) > 0) ? lookup(policies.value, "port_ranges", []) : []

        content {
          lo = tonumber(port_ranges.value)
          hi = tonumber(port_ranges.value)
        }
      }
    }
  }
  depends_on = [aviatrix_distributed_firewalling_config.enable_distributed_firewalling]
}