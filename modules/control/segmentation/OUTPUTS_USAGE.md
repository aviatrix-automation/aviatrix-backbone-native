# Segmentation Module Outputs - Usage Examples

This document provides examples of how to use the segmentation module outputs.

## Overview

The segmentation module now exports comprehensive outputs that can be used for:
- **Integration**: Reference domain IDs and associations in other modules
- **Monitoring**: Track segmentation status and resource counts
- **Debugging**: Understand auto-inference vs manual associations
- **Visualization**: Generate network topology diagrams
- **Documentation**: Create segmentation policy reports

---

## Output Categories

### 1. Domain Outputs
- `domains` - Map of domain names to IDs
- `domain_list` - Simple list of domain names
- `domain_summary` - Comprehensive per-domain information

### 2. Policy Outputs
- `connection_policies` - All connection policies
- `connection_policy_matrix` - Which domains can communicate

### 3. Association Outputs
- `transit_associations` - All transit associations
- `transit_associations_by_domain` - Grouped by domain
- `transit_associations_by_gateway` - Grouped by gateway
- `spoke_associations` - All spoke associations
- `spoke_associations_by_domain` - Grouped by domain
- `spoke_associations_by_transit` - Grouped by transit

### 4. Summary Outputs
- `segmentation_status` - Overall configuration status
- `association_summary` - Association counts and breakdowns
- `association_sources` - Track auto vs manual associations
- `excluded_resources` - What was excluded

### 5. Analysis Outputs
- `inferred_domain_mappings` - Auto-inferred domain assignments
- `domain_connectivity_graph` - Graph for visualization

---

## Output Examples

### 1. Segmentation Status

**Output**: `segmentation_status`

Returns overall segmentation configuration and statistics.

```hcl
output "example_segmentation_status" {
  value = module.segmentation.segmentation_status
}

# Example output:
# {
#   total_domains              = 4
#   domain_names               = ["prod", "non-prod", "infra", "dmz"]
#   total_policies             = 5
#   total_transit_associations = 12
#   total_spoke_associations   = 8
#   total_associations         = 20
#   auto_inferred_transits     = 10
#   manual_transits            = 2
#   auto_inferred_spokes       = 7
#   manual_spokes              = 1
#   excluded_connections       = 2
#   excluded_spoke_gateways    = 1
#   spoke_cloud_types          = [1, 8, 4]
# }
```

**Use Case**: Monitoring dashboards, compliance reports, configuration validation.

---

### 2. Domain Summary

**Output**: `domain_summary`

Returns comprehensive information for each domain.

```hcl
output "example_domain_summary" {
  value = module.segmentation.domain_summary
}

# Example output:
# {
#   "prod" = {
#     domain_id = "prod-uuid-123"
#     transit_associations = {
#       count = 3
#       connections = [
#         {
#           transit_gateway = "aws-us-east-1-transit"
#           connection      = "external-prod-datacenter"
#         },
#         {
#           transit_gateway = "azure-eastus2-transit"
#           connection      = "external-prod-vpn"
#         }
#       ]
#     }
#     spoke_associations = {
#       count = 5
#       spokes = [
#         {
#           spoke_gateway   = "aws-prod-app-spoke"
#           transit_gateway = "aws-us-east-1-transit"
#         }
#       ]
#     }
#     connected_domains = ["infra", "dmz"]
#     total_associations = 8
#   }
# }
```

**Use Case**: Per-domain dashboards, capacity planning, domain health checks.

---

### 3. Connection Policy Matrix

**Output**: `connection_policy_matrix`

Shows which domains can communicate with each other.

```hcl
output "example_policy_matrix" {
  value = module.segmentation.connection_policy_matrix
}

# Example output:
# {
#   "prod"     = ["infra", "dmz"]
#   "non-prod" = ["infra"]
#   "infra"    = ["prod", "non-prod", "dmz"]
#   "dmz"      = ["prod", "infra"]
# }
```

**Use Case**: Security audits, policy validation, network diagrams.

---

### 4. Associations by Domain

**Output**: `transit_associations_by_domain` and `spoke_associations_by_domain`

Groups all associations by their domain.

```hcl
output "example_transit_by_domain" {
  value = module.segmentation.transit_associations_by_domain
}

# Example output:
# {
#   "prod" = [
#     {
#       transit_gateway = "aws-us-east-1-transit"
#       connection      = "external-prod-datacenter"
#       id              = "assoc-123"
#     },
#     {
#       transit_gateway = "azure-eastus2-transit"
#       connection      = "external-prod-azure-vpn"
#       id              = "assoc-456"
#     }
#   ]
#   "infra" = [...]
# }
```

**Use Case**: Domain-specific reports, troubleshooting, capacity planning.

---

### 5. Association Sources

**Output**: `association_sources`

Tracks which associations were auto-inferred vs manually configured.

```hcl
output "example_association_sources" {
  value = module.segmentation.association_sources
}

# Example output:
# {
#   transit = {
#     auto_inferred = {
#       "external-prod-dc1~aws-us-east-1-transit" = {
#         domain          = "prod"
#         connection      = "external-prod-dc1"
#         transit_gateway = "aws-us-east-1-transit"
#         source          = "auto-inferred"
#       }
#     }
#     manual = {
#       "legacy-vpn~azure-west-transit" = {
#         domain          = "prod"
#         connection      = "legacy-vpn"
#         transit_gateway = "azure-west-transit"
#         source          = "manual"
#       }
#     }
#   }
# }
```

**Use Case**: Understanding automation effectiveness, migration tracking.

---

### 6. Domain Connectivity Graph

**Output**: `domain_connectivity_graph`

Graph representation for visualization tools.

```hcl
output "example_connectivity_graph" {
  value = module.segmentation.domain_connectivity_graph
}

# Example output:
# {
#   nodes = [
#     { id = "prod", label = "prod", type = "domain" },
#     { id = "infra", label = "infra", type = "domain" },
#     { id = "dmz", label = "dmz", type = "domain" }
#   ]
#   edges = [
#     { from = "prod", to = "infra", type = "bidirectional", label = "allowed" },
#     { from = "prod", to = "dmz", type = "bidirectional", label = "allowed" }
#   ]
# }
```

**Use Case**: Network diagrams, topology visualization, documentation.

---

## Integration Examples

### Example 1: Monitor Domain Health

```hcl
# Create CloudWatch dashboard with domain metrics
resource "aws_cloudwatch_dashboard" "segmentation" {
  dashboard_name = "network-segmentation"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title = "Domain Association Count"
          metrics = [
            for domain, summary in module.segmentation.domain_summary :
            ["NetworkSegmentation", "Associations", { stat = summary.total_associations }]
          ]
        }
      }
    ]
  })
}
```

---

### Example 2: Generate Policy Documentation

```hcl
# Generate a markdown report of segmentation policies
resource "local_file" "segmentation_report" {
  filename = "${path.module}/segmentation-report.md"
  content = templatefile("${path.module}/templates/segmentation-report.tpl", {
    status         = module.segmentation.segmentation_status
    domains        = module.segmentation.domain_summary
    policy_matrix  = module.segmentation.connection_policy_matrix
  })
}
```

**Template example** (`templates/segmentation-report.tpl`):

```markdown
# Network Segmentation Report

## Summary
- Total Domains: ${status.total_domains}
- Total Policies: ${status.total_policies}
- Total Associations: ${status.total_associations}

## Domains
%{ for domain, summary in domains ~}
### ${domain}
- Transit Associations: ${summary.transit_associations.count}
- Spoke Associations: ${summary.spoke_associations.count}
- Connected To: ${join(", ", summary.connected_domains)}
%{ endfor ~}

## Policy Matrix
%{ for domain, connected in policy_matrix ~}
- **${domain}** → ${join(", ", connected)}
%{ endfor ~}
```

---

### Example 3: Validate Configuration

```hcl
# Validation: Ensure critical domains have connections
locals {
  critical_domains = ["prod", "infra"]

  validation = {
    for domain in local.critical_domains :
    domain => {
      has_transit_connections = module.segmentation.domain_summary[domain].transit_associations.count > 0
      has_spoke_connections   = module.segmentation.domain_summary[domain].spoke_associations.count > 0
      is_connected           = length(module.segmentation.domain_summary[domain].connected_domains) > 0
      status                 = (
        module.segmentation.domain_summary[domain].transit_associations.count > 0 &&
        length(module.segmentation.domain_summary[domain].connected_domains) > 0
      ) ? "healthy" : "warning"
    }
  }
}

output "domain_health" {
  value = local.validation
}
```

---

### Example 4: Export for External Tools

```hcl
# Export segmentation data for external CMDB or monitoring tools
resource "local_file" "segmentation_export" {
  filename = "${path.module}/segmentation-export.json"
  content = jsonencode({
    timestamp         = timestamp()
    segmentation_status = module.segmentation.segmentation_status

    domains = {
      for domain, summary in module.segmentation.domain_summary : domain => {
        total_resources   = summary.total_associations
        transit_count     = summary.transit_associations.count
        spoke_count       = summary.spoke_associations.count
        connectivity      = summary.connected_domains
        isolation_level   = length(summary.connected_domains) == 0 ? "isolated" : "connected"
      }
    }

    associations = {
      transit_by_gateway = module.segmentation.transit_associations_by_gateway
      spoke_by_transit   = module.segmentation.spoke_associations_by_transit
    }

    topology = module.segmentation.domain_connectivity_graph
  })
}
```

---

### Example 5: Detect Orphaned Resources

```hcl
# Find domains with no associations (potential configuration issue)
locals {
  orphaned_domains = [
    for domain, summary in module.segmentation.domain_summary :
    domain
    if summary.total_associations == 0
  ]

  under_utilized_domains = [
    for domain, summary in module.segmentation.domain_summary :
    domain
    if summary.total_associations < 2 && summary.total_associations > 0
  ]
}

output "resource_alerts" {
  value = {
    orphaned_domains       = local.orphaned_domains
    under_utilized_domains = local.under_utilized_domains
    action = length(local.orphaned_domains) > 0 ? "review segmentation configuration" : "ok"
  }
}
```

---

### Example 6: Track Auto-Inference Effectiveness

```hcl
# Measure how effective auto-inference is
locals {
  auto_inference_stats = {
    transit = {
      auto_count     = module.segmentation.segmentation_status.auto_inferred_transits
      manual_count   = module.segmentation.segmentation_status.manual_transits
      total          = module.segmentation.segmentation_status.total_transit_associations
      auto_percent   = (
        module.segmentation.segmentation_status.total_transit_associations > 0 ?
        round((module.segmentation.segmentation_status.auto_inferred_transits /
               module.segmentation.segmentation_status.total_transit_associations) * 100) : 0
      )
    }
    spoke = {
      auto_count     = module.segmentation.segmentation_status.auto_inferred_spokes
      manual_count   = module.segmentation.segmentation_status.manual_spokes
      total          = module.segmentation.segmentation_status.total_spoke_associations
      auto_percent   = (
        module.segmentation.segmentation_status.total_spoke_associations > 0 ?
        round((module.segmentation.segmentation_status.auto_inferred_spokes /
               module.segmentation.segmentation_status.total_spoke_associations) * 100) : 0
      )
    }
  }
}

output "auto_inference_effectiveness" {
  value = local.auto_inference_stats
}

# Example output:
# {
#   transit = {
#     auto_count = 10
#     manual_count = 2
#     total = 12
#     auto_percent = 83
#   }
#   spoke = {
#     auto_count = 7
#     manual_count = 1
#     total = 8
#     auto_percent = 88
#   }
# }
```

---

## Testing Outputs

After applying the segmentation module, query the outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output segmentation_status

# View output in JSON format
terraform output -json domain_summary | jq

# Check association counts per domain
terraform output -json association_summary | jq '.transit.by_domain'

# Export to file
terraform output -json > segmentation-outputs.json
```

---

## Best Practices

1. **Monitor Status**: Use `segmentation_status` in CI/CD to verify configuration
2. **Track Changes**: Compare `domain_summary` across deployments to detect drift
3. **Validate Policies**: Use `connection_policy_matrix` to verify security posture
4. **Review Sources**: Check `association_sources` to ensure auto-inference is working
5. **Visualize**: Use `domain_connectivity_graph` to generate network diagrams
6. **Document**: Export outputs to generate automated documentation
7. **Alert**: Set up alerts for orphaned domains or missing associations

---

## Troubleshooting

### Issue: Domain shows 0 associations

**Problem**: A domain has no transit or spoke associations.

**Solution**:
```bash
# Check if resources are being excluded
terraform output excluded_resources

# Check auto-inferred mappings
terraform output -json inferred_domain_mappings | jq

# Review manual associations
terraform output -json association_sources | jq '.transit.manual'
```

### Issue: Missing expected policy

**Problem**: Two domains aren't connected in the policy matrix.

**Solution**:
```bash
# View current policy matrix
terraform output connection_policy_matrix

# Check connection policies
terraform output connection_policies

# Verify domain names match exactly (case-sensitive)
terraform output domain_list
```

### Issue: Auto-inference not working

**Problem**: Resources aren't being automatically assigned to domains.

**Solution**:
```bash
# Check inferred domain mappings
terraform output -json inferred_domain_mappings

# Verify naming conventions
# Transit connections should start with "external-{domain}-"
# Spoke gateways should contain domain name segments

# Check exclusion lists
terraform output excluded_resources

# View debug outputs for raw data
terraform output -json debug_filtered_connections
```

---

## Advanced Use Cases

### Generate Terraform Graph Visualization

```bash
# Export connectivity graph and convert to DOT format
terraform output -json domain_connectivity_graph | \
  jq -r '
    "digraph segmentation {" +
    (.nodes | map("  \(.id) [label=\"\(.label)\"]") | join("\n")) +
    "\n" +
    (.edges | map("  \(.from) -> \(.to) [dir=both]") | join("\n")) +
    "\n}"
  ' > segmentation.dot

# Generate PNG image
dot -Tpng segmentation.dot -o segmentation.png
```

### Compare Segmentation Across Environments

```bash
# Export prod segmentation
cd environments/prod
terraform output -json segmentation_status > prod-status.json

# Export staging segmentation
cd ../staging
terraform output -json segmentation_status > staging-status.json

# Compare
diff <(jq -S . prod-status.json) <(jq -S . staging-status.json)
```

### Create Compliance Report

```hcl
# Generate compliance checklist
locals {
  compliance_checks = {
    "All domains have transit connectivity" = alltrue([
      for domain, summary in module.segmentation.domain_summary :
      summary.transit_associations.count > 0
    ])

    "No orphaned domains" = length([
      for domain, summary in module.segmentation.domain_summary :
      domain if summary.total_associations == 0
    ]) == 0

    "Prod domain is isolated from non-prod" = !contains(
      module.segmentation.connection_policy_matrix["prod"],
      "non-prod"
    )

    "All critical domains have redundancy" = alltrue([
      for domain in ["prod", "infra"] :
      module.segmentation.domain_summary[domain].transit_associations.count >= 2
    ])
  }
}

output "compliance_report" {
  value = {
    timestamp = timestamp()
    checks    = local.compliance_checks
    passed    = alltrue(values(local.compliance_checks))
    details   = module.segmentation.segmentation_status
  }
}
```
