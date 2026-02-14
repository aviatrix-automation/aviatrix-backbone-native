## Data Refresh & Caching Behavior

**Important:**

- The Site2Cloud connections and other external data fetched by this module are cached in the Terraform state after the first apply.
- If connections or other data change in Aviatrix, you must refresh or re-apply to update the Terraform state.
- Use `terraform refresh` or re-run `terraform apply` to update the cached data.
- To force a specific data source or resource (like `terracurl_request.aviatrix_connections`) to refresh, use:
  ```bash
  terraform taint terracurl_request.aviatrix_connections
  terraform apply
  ```
- This is standard Terraform behavior for all data sources and external data fetches.

## Two-Stage Apply (when using dynamic data)

If you encounter errors about unknown values for `for_each` (due to dynamic data from API calls), use a two-stage apply:

```bash
# Stage 1: Apply only the data sources and terracurl request
terraform apply \
  -target=data.aviatrix_spoke_gateways.all_spoke_gws \
  -target=data.aviatrix_transit_gateways.all_transit_gws \
  -target=terracurl_request.aviatrix_connections

# Stage 2: Apply the full configuration
terraform apply
```

# Segmentation - Aviatrix Network Domain Management

This module creates and manages Aviatrix network segmentation domains, connection policies, and automatic domain associations for transit and spoke gateways.

## Overview

The module provides:

- **Network Domains**: Creates segmentation domains from the provided list
- **Connection Policies**: Defines which domains can communicate with each other
- **Transit Domain Associations**: Auto-associates external connections (Site2Cloud BGP tunnels) to domains based on naming convention, with support for manual overrides and exclusions
- **Spoke Domain Associations**: Auto-associates spoke gateways to domains based on gateway naming convention, with configurable cloud types, manual overrides, and exclusions

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Network Domains                              │
│  - Created from var.domains list                                │
│  - Used for traffic segmentation                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Connection Policies                            │
│  - Define allowed domain-to-domain communication                │
│  - Configured via var.connection_policy                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Domain Associations                            │
│  Transit Associations:                                          │
│  - Auto: External connections with "external-" prefix           │
│  - Manual: Explicit connection~gateway mappings                 │
│  - Exclusions: Skip specific connections                        │
│                                                                 │
│  Spoke Associations:                                            │
│  - Auto: Configurable cloud types (AWS/Azure/GCP)               │
│  - Manual: Explicit spoke~transit mappings                      │
│  - Exclusions: Skip specific gateways                           │
└─────────────────────────────────────────────────────────────────┘
```

## Domain Inference Logic

### Transit Connections (Auto-Inference)
- Connections with names starting with `external-` are analyzed
- Domain is inferred by matching domain names within the connection name
- Only BGP-enabled Site2Cloud tunnels are associated
- Can be overridden with `manual_transit_associations`
- Can exclude specific connections with `exclude_connections`

### Spoke Gateways (Auto-Inference)
- Spoke gateways of specified cloud types are analyzed (configurable via `spoke_cloud_types`)
- Default is Azure only (cloud_type=8), but can include AWS (1), GCP (4), etc.
- Domain is inferred by matching domain name segments in the gateway name
- HA gateways (ending with `-hagw`) are excluded
- Can be overridden with `manual_spoke_associations`
- Can exclude specific gateways with `exclude_spoke_gateways`

### Override Behavior
- Manual associations always take precedence over auto-inference
- Auto-inference and manual associations are merged
- This allows using auto-inference for most resources while overriding corner cases

## Two-Stage Apply

Due to `for_each` dependencies on data sources, use a two-stage apply:

```bash
# Stage 1: Apply data sources and terracurl request
terraform apply \
  -target=data.aviatrix_spoke_gateways.all_spoke_gws \
  -target=data.aviatrix_transit_gateways.all_transit_gws \
  -target=terracurl_request.aviatrix_connections

# Stage 2: Apply full configuration
terraform apply
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aviatrix | 8.1.1 |
| terracurl | 2.1.0 |
| aws | >= 4.0 |
| http | >= 3.0 |

## Providers

| Name | Description |
|------|-------------|
| aviatrix | Aviatrix provider for segmentation resources |
| aws.ssm | AWS provider for SSM parameter retrieval |
| http | HTTP provider for controller login |
| terracurl | Terracurl provider for API calls |

## Resources

| Name | Type |
|------|------|
| [aviatrix_segmentation_network_domain.domains](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/resources/segmentation_network_domain) | resource |
| [aviatrix_segmentation_network_domain_association.transit_domain_associations](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/resources/segmentation_network_domain_association) | resource |
| [aviatrix_segmentation_network_domain_association.spoke_domain_associations](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/resources/segmentation_network_domain_association) | resource |
| [aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/resources/segmentation_network_domain_connection_policy) | resource |
| [terracurl_request.aviatrix_connections](https://registry.terraform.io/providers/devops-rob/terracurl/latest/docs/resources/request) | resource |

## Data Sources

| Name | Type |
|------|------|
| [aviatrix_transit_gateways.all_transit_gws](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/data-sources/transit_gateways) | data source |
| [aviatrix_spoke_gateways.all_spoke_gws](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/data-sources/spoke_gateways) | data source |
| [aws_ssm_parameter.aviatrix_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [http.controller_login](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_ssw_region | AWS region for SSM parameter retrieval | `string` | n/a | yes |
| domains | List of unique domain names for segmentation | `list(string)` | `[]` | no |
| connection_policy | List of connection policies defining allowed domain communication | `list(object({ source = string, target = string }))` | `[]` | no |
| destroy_url | Dummy URL used by terracurl during destroy operations | `string` | `"https://checkip.amazonaws.com"` | no |
| manual_transit_associations | Manual domain associations for transit connections. Map key is `connection_name~gateway_name`, value is domain name. Overrides auto-inference. | `map(string)` | `{}` | no |
| manual_spoke_associations | Manual domain associations for spoke gateways. Map key is `spoke_name~transit_name`, value is domain name. Overrides auto-inference. | `map(string)` | `{}` | no |
| exclude_connections | List of connection names to exclude from auto-association | `list(string)` | `[]` | no |
| exclude_spoke_gateways | List of spoke gateway names to exclude from auto-association | `list(string)` | `[]` | no |
| spoke_cloud_types | List of cloud types to include for spoke associations. Cloud types: 1=AWS, 8=Azure, 4=GCP, 16=OCI, 32=AliCloud | `list(number)` | `[8]` | no |

## Outputs

### Domain Outputs

| Name | Description |
|------|-------------|
| `domains` | Map of created network domain names to their IDs |
| `domain_list` | List of all domain names |
| `domain_summary` | Comprehensive summary of each domain with associations and policies |

### Policy Outputs

| Name | Description |
|------|-------------|
| `connection_policies` | Map of connection policies between domains |
| `connection_policy_matrix` | Matrix showing which domains can communicate (bidirectional) |

### Association Outputs

| Name | Description |
|------|-------------|
| `transit_associations` | Map of all transit domain associations |
| `transit_associations_by_domain` | Transit associations grouped by network domain |
| `transit_associations_by_gateway` | Transit associations grouped by transit gateway |
| `spoke_associations` | Map of all spoke domain associations |
| `spoke_associations_by_domain` | Spoke associations grouped by network domain |
| `spoke_associations_by_transit` | Spoke associations grouped by transit gateway |

### Summary Outputs

| Name | Description |
|------|-------------|
| `segmentation_status` | Overall segmentation configuration status and statistics |
| `association_summary` | Summary of associations by type and source |
| `association_sources` | Track which associations were auto-inferred vs manually configured |
| `excluded_resources` | Resources that were excluded from segmentation |

### Analysis Outputs

| Name | Description |
|------|-------------|
| `inferred_domain_mappings` | Auto-inferred domain mappings for connections and spokes |
| `domain_connectivity_graph` | Graph representation of domain connectivity for visualization |

### Table-Formatted Outputs (Human-Readable)

| Name | Description |
|------|-------------|
| `summary_table` | **⭐ Primary** - Concise summary with key metrics in a beautiful box table |
| `domain_summary_table` | Domain summary in ASCII table format - domains, counts, and connectivity |
| `transit_associations_table` | Transit associations in ASCII table format |
| `spoke_associations_table` | Spoke associations in ASCII table format |
| `connection_policy_table` | Connection policies in ASCII table format |
| `segmentation_status_table` | Complete status report in formatted text |
| `association_sources_table` | Association sources (auto vs manual) in table format |

### Debug Outputs

| Name | Description |
|------|-------------|
| `debug_filtered_connections` | Debug: filtered Site2Cloud connections used for segmentation associations |
| `debug_domain_attachment_pairs` | Debug: all domain_attachment_pairs generated for segmentation associations |
| `debug_connections_list` | Debug: raw Site2Cloud connections list from API |

**See [OUTPUTS_USAGE.md](./OUTPUTS_USAGE.md) for detailed examples and integration patterns.**

### Viewing Table Outputs

For beautiful, human-readable output:

```bash
# ⭐ View concise summary (recommended - best overview)
terraform output -raw summary_table

# View detailed domain summary table
terraform output -raw domain_summary_table

# View transit associations table
terraform output -raw transit_associations_table

# View spoke associations table
terraform output -raw spoke_associations_table

# View connection policies table
terraform output -raw connection_policy_table

# View complete status report
terraform output -raw segmentation_status_table

# View association sources (auto vs manual)
terraform output -raw association_sources_table
```

## Usage

### Basic Usage (Auto-Inference Only)

```hcl
module "segmentation" {
  source = "./segmentation"

  aws_ssw_region = "us-east-1"

  domains = [
    "production",
    "development",
    "shared-services"
  ]

  connection_policy = [
    {
      source = "production"
      target = "shared-services"
    },
    {
      source = "development"
      target = "shared-services"
    }
  ]
}
```

### Example 1: Manual Overrides for Non-Standard Names

Override auto-inference for connections with non-standard naming:

```hcl
module "segmentation" {
  source = "./segmentation"

  aws_ssw_region = "us-east-1"

  domains = ["prod", "dev", "shared"]

  # Auto-inference handles most connections
  # Manual overrides for legacy connections with non-standard names
  manual_transit_associations = {
    "legacy-vpn-connection~transit-hub-1" = "prod"
    "backup-site2cloud~transit-hub-2"     = "dev"
  }

  connection_policy = [
    {
      source = "prod"
      target = "shared"
    }
  ]
}
```

### Example 2: Multi-Cloud Spoke Support

Enable spoke associations for AWS, Azure, and GCP:

```hcl
module "segmentation" {
  source = "./segmentation"

  aws_ssw_region = "us-east-1"

  domains = ["prod", "dev"]

  # Enable AWS (1), Azure (8), and GCP (4) spoke associations
  spoke_cloud_types = [1, 8, 4]

  # Manual associations for spokes with non-standard names
  manual_spoke_associations = {
    "aws-legacy-spoke~transit-hub-1"   = "prod"
    "azure-backup-spoke~transit-hub-2" = "dev"
  }

  connection_policy = [
    {
      source = "prod"
      target = "dev"
    }
  ]
}
```

### Example 3: Exclude Test Infrastructure

Exclude test and temporary resources from domain associations:

```hcl
module "segmentation" {
  source = "./segmentation"

  aws_ssw_region = "us-east-1"

  domains = ["prod", "dev"]

  # Exclude test connections and gateways from domain association
  exclude_connections = [
    "external-test-connection",
    "external-temp-vpn",
    "external-sandbox-site2cloud"
  ]

  exclude_spoke_gateways = [
    "test-spoke-1",
    "dev-experimental-spoke",
    "sandbox-spoke"
  ]

  connection_policy = [
    {
      source = "prod"
      target = "dev"
    }
  ]
}
```

### Example 4: Comprehensive Configuration

Combine all features for maximum flexibility:

```hcl
module "segmentation" {
  source = "./segmentation"

  aws_ssw_region = "us-east-1"

  domains = ["prod", "dev", "shared", "dmz"]

  # Support all cloud types
  spoke_cloud_types = [1, 8, 4]  # AWS, Azure, GCP

  # Manual overrides for specific cases
  manual_transit_associations = {
    "legacy-connection~transit-prod"  = "prod"
    "partner-vpn~transit-shared"      = "dmz"
  }

  manual_spoke_associations = {
    "special-spoke~transit-prod"      = "prod"
    "aws-legacy-app~transit-shared"   = "shared"
  }

  # Exclude test infrastructure
  exclude_connections = ["external-test-connection"]
  exclude_spoke_gateways = ["test-spoke"]

  # Connection policies
  connection_policy = [
    { source = "prod", target = "shared" },
    { source = "dev", target = "shared" },
    { source = "dmz", target = "shared" }
  ]
}
```

## Notes

- The module uses terracurl to fetch Site2Cloud connections via the Aviatrix API
- Aviatrix controller credentials are retrieved from AWS SSM Parameter Store
- Domain names are matched in descending order by length to ensure longer, more specific names match first
- Only primary gateways are associated (HA gateways are excluded)
- **Flexibility Features**:
  - Auto-inference works for most standard naming conventions
  - Manual associations override auto-inference for corner cases
  - Exclusion lists skip specific connections or gateways
  - Spoke cloud types are configurable (AWS, Azure, GCP, etc.)
  - Manual and auto-inferred associations are merged (manual wins)
- **Backward Compatibility**: All new variables have empty defaults, so existing configurations work unchanged
