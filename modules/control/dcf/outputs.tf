# Smart Group Outputs
output "created_smart_groups" {
  description = "Map of created smart group names to their UUIDs"
  value       = { for name, sg in aviatrix_smart_group.smarties : name => sg.uuid }
}

output "created_smart_groups_details" {
  description = "Full details of created smart groups including selectors"
  value = {
    for name, sg in aviatrix_smart_group.smarties : name => {
      uuid = sg.uuid
      name = sg.name
      id   = sg.id
    }
  }
}

# All Smart Groups (existing + created)
output "all_smart_groups" {
  description = "Map of all smart group names to their UUIDs (existing + created)"
  value       = merge(local.smart_groups_map, local.created_smart_groups_map)
}

# Policy Outputs
output "policies_summary" {
  description = "Summary of configured distributed firewall policies"
  value = {
    for policy_name, policy in var.policies : policy_name => {
      action           = policy.action
      priority         = policy.priority
      protocol         = policy.protocol
      logging          = policy.logging
      watch            = policy.watch
      src_smart_groups = policy.src_smart_groups
      dst_smart_groups = policy.dst_smart_groups
      port_ranges      = lookup(policy, "port_ranges", [])
    }
  }
}

# DCF Configuration Status
output "dcf_status" {
  description = "Distributed Cloud Firewall configuration status"
  value = {
    enabled                    = var.enable_distributed_firewalling
    default_action             = var.distributed_firewalling_default_action_rule_action
    default_action_logging     = var.distributed_firewalling_default_action_rule_logging
    total_policies             = length(var.policies)
    total_smart_groups_created = length(var.smarties)
    total_smart_groups_all     = length(merge(local.smart_groups_map, local.created_smart_groups_map))
  }
}

# Policy List Resource ID
output "policy_list_id" {
  description = "ID of the distributed firewalling policy list resource"
  value       = aviatrix_distributed_firewalling_policy_list.policies.id
}

# Smart Group UUID Lookup Helper
output "smart_group_uuid_lookup" {
  description = "Helper output for looking up smart group UUIDs by name"
  value = {
    for name, uuid in merge(local.smart_groups_map, local.created_smart_groups_map) : name => {
      uuid   = uuid
      source = contains(keys(local.created_smart_groups_map), name) ? "created" : "existing"
    }
  }
}
