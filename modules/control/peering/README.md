# Peering 2.0 - Aviatrix Transit Gateway Peering

This module creates full-mesh peering between Aviatrix transit gateways, handling both same-cloud and cross-cloud connectivity.

## Overview

The module automatically discovers all transit gateways via the Aviatrix controller and creates:

- **Same-cloud peering**: Full mesh between transit gateways within the same cloud provider
- **Cross-cloud peering**: Full mesh between transit gateways across different cloud providers (with insane mode encryption)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Same-Cloud Peering                           │
│  (per cloud type with multiple gateways)                        │
│  - Configurable peering over private network (default: false)  │
│  - Configurable max performance (default: enabled)              │
│  - Configurable single tunnel mode (default: disabled)         │
│  - Supports: AWS, GCP, Azure                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Cross-Cloud Peering                           │
│  (between all primary gateways across clouds)                   │
│  - Configurable peering over private network (default: false)  │
│  - Configurable insane mode encryption (default: auto-detect)  │
│  - Configurable single tunnel mode (default: disabled)         │
│  - Configurable tunnel count (default: 15 for HPE)             │
│  - HPE over internet: AWS, GCP, and Azure supported            │
└─────────────────────────────────────────────────────────────────┘
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aviatrix | 8.1.20 |
| aws | >= 4.0 |

## Providers

| Name | Description |
|------|-------------|
| aws.ssm | AWS provider for SSM parameter retrieval |
| aviatrix | Aviatrix provider for gateway and peering management |

## Resources

| Name | Type |
|------|------|
| [aviatrix_transit_gateways.all_transit_gws](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/data-sources/aviatrix_transit_gateways) | data source |
| [aws_ssm_parameter.aviatrix_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Modules

| Name | Source | Version |
|------|--------|---------|
| same_cloud_peering | terraform-aviatrix-modules/mc-transit-peering/aviatrix | 1.0.9 |
| cross_cloud_peering | terraform-aviatrix-modules/mc-transit-peering/aviatrix | 1.0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_ssm_region | AWS region for SSM parameter retrieval | `string` | n/a | yes |
| same_cloud_enable_peering_over_private_network | Enable peering over private network for same-cloud peering. Only applies when two transit gateways are in Insane Mode. | `bool` | `false` | no |
| same_cloud_enable_max_performance | Enable maximum amount of HPE tunnels for same-cloud peering. Only valid when transit gateways are in Insane Mode and same cloud type. Supported for AWS, GCP, and Azure. | `bool` | `true` | no |
| same_cloud_enable_single_tunnel_mode | Enable peering with Single-Tunnel mode for same-cloud peering. Only applies with enable_peering_over_private_network. | `bool` | `false` | no |
| cross_cloud_enable_peering_over_private_network | Enable peering over private network for cross-cloud peering. Only applies when two transit gateways are in Insane Mode and different cloud types. | `bool` | `false` | no |
| cross_cloud_enable_insane_mode_encryption_over_internet | Enable Insane Mode Encryption over Internet for cross-cloud peering. Transit gateways must be in Insane Mode. Supported among AWS, GCP, and Azure. | `bool` | `null` (auto-detect) | no |
| cross_cloud_enable_single_tunnel_mode | Enable peering with Single-Tunnel mode for cross-cloud peering. Only applies with enable_peering_over_private_network. | `bool` | `false` | no |
| cross_cloud_tunnel_count | Number of public tunnels for cross-cloud Insane Mode Encryption over Internet. Valid range: 2-20. Supported for cross-cloud peerings with HPE. | `number` | `null` (15 for HPE) | no |

## Outputs

| Name | Description |
|------|-------------|
| same_cloud_peerings | Same-cloud transit gateway peerings created, grouped by cloud type |
| cross_cloud_peerings | Cross-cloud transit gateway peerings created with all involved gateways |
| all_primary_gateways | List of all primary transit gateways involved in peering |
| gateways_by_cloud_type | Primary transit gateways grouped by cloud type |

## Usage

### Basic Usage

```hcl
module "peering" {
  source = "git::https://github.com/org/repo.git//modules/control/peering"

  aws_ssm_region = "us-east-1"
}
```

### Advanced Usage with Custom Configuration

```hcl
module "peering" {
  source = "git::https://github.com/org/repo.git//modules/control/peering"

  aws_ssm_region = "us-east-1"

  # Same-cloud peering configuration (AWS, GCP, Azure)
  same_cloud_enable_peering_over_private_network = false
  same_cloud_enable_max_performance              = true  # Enables HPE for same-cloud
  same_cloud_enable_single_tunnel_mode           = false

  # Cross-cloud peering configuration (HPE encryption over internet)
  cross_cloud_enable_peering_over_private_network         = false
  cross_cloud_enable_insane_mode_encryption_over_internet = true  # AWS, GCP, Azure
  cross_cloud_enable_single_tunnel_mode                   = false
  cross_cloud_tunnel_count                                = 15  # For HPE cross-cloud
}
```

## Notes

- HA gateways (ending with `-hagw`) are automatically excluded from peering calculations
- Same-cloud pairs are pruned from cross-cloud peering to avoid duplicate connections
- The module uses the Aviatrix controller credentials stored in AWS SSM Parameter Store

### High-Performance Encryption (HPE) Support

**Same-Cloud Peering:**
- `enable_max_performance` is supported for AWS, GCP, and Azure
- Creates multiple HPE tunnels for maximum throughput within the same cloud
- Does NOT use `enable_insane_mode_encryption_over_internet` (cross-cloud only parameter)

**Cross-Cloud Peering:**
- `enable_insane_mode_encryption_over_internet` is supported among AWS, GCP, and Azure
- When `enable_insane_mode_encryption_over_internet` is `null`, it auto-enables for HPE-capable peerings (AWS, GCP, Azure)
- When `tunnel_count` is `null`, it defaults to 15 tunnels for HPE-capable peerings
- Does NOT use `enable_max_performance` (same-cloud only parameter)

**Important:** Separate configurations allow different settings for same-cloud vs cross-cloud peering scenarios based on Aviatrix platform capabilities.
