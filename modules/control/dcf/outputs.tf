# ----------------------------------------------------------------------------
# Table-Formatted Outputs (Human-Readable)
# ----------------------------------------------------------------------------

output "policies_table" {
  description = "Firewall policies in table format, sorted by priority"
  value = join("\n", concat(
    [
      "",
      "═══════════════════════════════════════════════════════════════════════════════════════════════",
      "                                  FIREWALL POLICIES TABLE",
      "═══════════════════════════════════════════════════════════════════════════════════════════════",
      format("%-8s | %-7s | %-25s | %-20s | %-20s", "Priority", "Action", "Policy", "Source", "Destination"),
      "───────────────────────────────────────────────────────────────────────────────────────────────"
    ],
    [
      for entry in sort([for k, v in var.policies : format("%05d|%s", v.priority, k)]) :
      format("%-8s | %-7s | %-25s | %-20s | %-20s",
        tostring(var.policies[split("|", entry)[1]].priority),
        var.policies[split("|", entry)[1]].action,
        split("|", entry)[1],
        join(", ", var.policies[split("|", entry)[1]].src_smart_groups),
        join(", ", var.policies[split("|", entry)[1]].dst_smart_groups)
      )
    ],
    [
      "═══════════════════════════════════════════════════════════════════════════════════════════════",
      format("Total Policies: %d  |  Default Action: %s", length(var.policies), var.distributed_firewalling_default_action_rule_action),
      ""
    ]
  ))
}