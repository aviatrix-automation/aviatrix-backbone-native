# DCF Module Outputs - Usage Examples

This document provides examples of how to use the DCF module outputs.

## Overview

The DCF module now exports several useful outputs that can be used for:
- **Integration**: Reference smart group UUIDs in other modules
- **Debugging**: Verify policy configurations and smart group assignments
- **Monitoring**: Track DCF status and configuration
- **Documentation**: Generate reports of firewall policies

---

## Output Examples

### 1. Created Smart Groups

**Output**: `created_smart_groups`

Returns a map of smart group names to their UUIDs for groups created by this module.

```hcl
output "example_created_smart_groups" {
  value = module.dcf.created_smart_groups
}

# Example output:
# {
#   "web-servers" = "uuid-abc-123"
#   "app-servers" = "uuid-def-456"
#   "db-servers"  = "uuid-ghi-789"
# }
```

**Use Case**: Reference these UUIDs in other Aviatrix resources or for API calls.

---

### 2. All Smart Groups

**Output**: `all_smart_groups`

Returns a map of ALL smart group names to UUIDs (both existing and newly created).

```hcl
output "example_all_smart_groups" {
  value = module.dcf.all_smart_groups
}

# Example output:
# {
#   "web-servers"       = "uuid-abc-123"  # Created by module
#   "app-servers"       = "uuid-def-456"  # Created by module
#   "existing-prod-sg"  = "uuid-xyz-999"  # Pre-existing
#   "existing-dev-sg"   = "uuid-lmn-888"  # Pre-existing
# }
```

**Use Case**: Full inventory of all available smart groups for policy creation.

---

### 3. Smart Group UUID Lookup

**Output**: `smart_group_uuid_lookup`

Returns detailed information about each smart group including its source (created vs existing).

```hcl
output "example_sg_lookup" {
  value = module.dcf.smart_group_uuid_lookup
}

# Example output:
# {
#   "web-servers" = {
#     uuid   = "uuid-abc-123"
#     source = "created"
#   }
#   "existing-prod-sg" = {
#     uuid   = "uuid-xyz-999"
#     source = "existing"
#   }
# }
```

**Use Case**: Determine which smart groups were created by this module vs pre-existing.

---

### 4. Policies Summary

**Output**: `policies_summary`

Returns a summary of all configured firewall policies.

```hcl
output "example_policies" {
  value = module.dcf.policies_summary
}

# Example output:
# {
#   "allow-web-to-app" = {
#     action           = "PERMIT"
#     priority         = 100
#     protocol         = "tcp"
#     logging          = true
#     watch            = false
#     src_smart_groups = ["web-servers"]
#     dst_smart_groups = ["app-servers"]
#     port_ranges      = ["443", "8080"]
#   }
#   "deny-external-to-db" = {
#     action           = "DENY"
#     priority         = 50
#     protocol         = "any"
#     logging          = true
#     watch            = false
#     src_smart_groups = ["public-zone"]
#     dst_smart_groups = ["db-servers"]
#     port_ranges      = []
#   }
# }
```

**Use Case**: Generate documentation, audit reports, or verify policy configurations.

---

### 5. DCF Status

**Output**: `dcf_status`

Returns overall DCF configuration status and statistics.

```hcl
output "example_dcf_status" {
  value = module.dcf.dcf_status
}

# Example output:
# {
#   enabled                    = true
#   default_action             = "DENY"
#   default_action_logging     = true
#   total_policies             = 12
#   total_smart_groups_created = 5
#   total_smart_groups_all     = 18
# }
```

**Use Case**: Monitoring dashboards, compliance reports, configuration validation.

---

## Integration Examples

### Example 1: Reference Smart Groups in Another Module

```hcl
# Root module configuration
module "dcf" {
  source = "./modules/control/dcf"

  smarties = {
    "web-tier" = {
      tags = { "Tier" = "web" }
    }
  }

  # ... other config
}

# Use the smart group UUID in another resource
resource "aviatrix_some_resource" "example" {
  smart_group_uuid = module.dcf.created_smart_groups["web-tier"]
}
```

---

### Example 2: Generate Policy Report

```hcl
# Generate a policy report file
resource "local_file" "policy_report" {
  content = jsonencode({
    dcf_status = module.dcf.dcf_status
    policies   = module.dcf.policies_summary
    smart_groups = module.dcf.smart_group_uuid_lookup
  })
  filename = "${path.module}/dcf-policy-report.json"
}
```

---

### Example 3: Conditional Logic Based on DCF Status

```hcl
# Only enable monitoring if DCF is enabled and has policies
resource "datadog_monitor" "dcf_policy_violations" {
  count = module.dcf.dcf_status.enabled && module.dcf.dcf_status.total_policies > 0 ? 1 : 0

  name    = "DCF Policy Violations"
  type    = "log alert"
  message = "DCF policy violation detected"

  # ... monitor configuration
}
```

---

### Example 4: Export for External Tools

```hcl
# Export smart group mappings for external firewall management tools
output "firewall_config_export" {
  value = {
    smart_groups = {
      for name, details in module.dcf.smart_group_uuid_lookup : name => {
        uuid        = details.uuid
        managed_by  = details.source == "created" ? "terraform" : "manual"
        policies    = [
          for policy_name, policy in module.dcf.policies_summary :
          policy_name if contains(policy.src_smart_groups, name) || contains(policy.dst_smart_groups, name)
        ]
      }
    }
    policy_count = module.dcf.dcf_status.total_policies
    dcf_enabled  = module.dcf.dcf_status.enabled
  }
}
```

---

### Example 5: Validation Checks

```hcl
# Validate that all policies are using known smart groups
locals {
  all_sg_names = keys(module.dcf.all_smart_groups)

  policy_validation = {
    for policy_name, policy in module.dcf.policies_summary : policy_name => {
      valid_src = alltrue([for sg in policy.src_smart_groups : contains(local.all_sg_names, sg)])
      valid_dst = alltrue([for sg in policy.dst_smart_groups : contains(local.all_sg_names, sg)])
      valid     = alltrue([for sg in policy.src_smart_groups : contains(local.all_sg_names, sg)]) && alltrue([for sg in policy.dst_smart_groups : contains(local.all_sg_names, sg)])
    }
  }
}

output "policy_validation_results" {
  value = local.policy_validation
}
```

---

## Testing Outputs

After applying the DCF module, you can query the outputs using:

```bash
# View all outputs
terraform output

# View specific output
terraform output created_smart_groups

# View output in JSON format
terraform output -json dcf_status | jq

# Export outputs to file
terraform output -json > dcf-outputs.json
```

---

## Best Practices

1. **Use outputs for integration**: Instead of hardcoding UUIDs, always reference outputs from the DCF module
2. **Monitor DCF status**: Use the `dcf_status` output in your CI/CD pipeline to verify configuration
3. **Document policies**: Export `policies_summary` to generate firewall rule documentation
4. **Track smart group sources**: Use `smart_group_uuid_lookup` to distinguish between Terraform-managed and manually-created groups
5. **Validate references**: Before creating policies, verify that smart group names exist in `all_smart_groups`

---

## Troubleshooting

### Issue: Smart group not found in outputs

**Problem**: A smart group name is used in a policy but doesn't appear in outputs.

**Solution**:
1. Check if the smart group is defined in the `smarties` variable
2. Verify the smart group was created successfully: `terraform output created_smart_groups`
3. Check if it's a pre-existing smart group: `terraform output all_smart_groups`

### Issue: Output shows 0 policies

**Problem**: `dcf_status.total_policies` shows 0 even though policies are defined.

**Solution**:
1. Verify the `policies` variable is correctly defined
2. Check for Terraform validation errors: `terraform validate`
3. Ensure the policy priority values are unique

### Issue: Can't find UUID for a smart group

**Problem**: Need to get UUID for a smart group but don't see it in outputs.

**Solution**:
```bash
# View the smart group lookup output
terraform output -json smart_group_uuid_lookup | jq '.["your-smart-group-name"]'

# Or use the all_smart_groups output
terraform output -json all_smart_groups | jq '.["your-smart-group-name"]'
```
