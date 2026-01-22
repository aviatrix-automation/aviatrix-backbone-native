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
│  - Configurable insane mode encryption (default: auto-detect)  │
│  - Configurable max performance (default: enabled)              │
│  - Configurable single tunnel mode (default: disabled)         │
│  - Configurable tunnel count (default: 15 for HPE-supported)   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Cross-Cloud Peering                           │
│  (between all primary gateways across clouds)                   │
│  - Configurable peering over private network (default: false)  │
│  - Configurable insane mode encryption (default: auto-detect)  │
│  - Configurable max performance (default: enabled)              │
│  - Configurable single tunnel mode (default: disabled)         │
│  - Configurable tunnel count (default: 15 for HPE-supported)   │
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
| same_cloud_enable_insane_mode_encryption_over_internet | Enable Insane Mode Encryption over Internet for same-cloud peering. Transit gateways must be in Insane Mode. Only supported between AWS and Azure. | `bool` | `null` (auto-detect) | no |
| same_cloud_enable_max_performance | Enable maximum amount of HPE tunnels for same-cloud peering. Only valid when transit gateways are in Insane Mode and same cloud type. | `bool` | `true` | no |
| same_cloud_enable_single_tunnel_mode | Enable peering with Single-Tunnel mode for same-cloud peering. Only applies with enable_peering_over_private_network. | `bool` | `false` | no |
| same_cloud_tunnel_count | Number of public tunnels for same-cloud Insane Mode Encryption over Internet. Valid range: 2-20. Only for AWS-Azure peerings. | `number` | `null` (15 for HPE) | no |
| cross_cloud_enable_peering_over_private_network | Enable peering over private network for cross-cloud peering. Only applies when two transit gateways are in Insane Mode and different cloud types. | `bool` | `false` | no |
| cross_cloud_enable_insane_mode_encryption_over_internet | Enable Insane Mode Encryption over Internet for cross-cloud peering. Transit gateways must be in Insane Mode. Only supported between AWS and Azure. | `bool` | `null` (auto-detect) | no |
| cross_cloud_enable_max_performance | Enable maximum amount of HPE tunnels for cross-cloud peering. Only valid when transit gateways are in Insane Mode. | `bool` | `true` | no |
| cross_cloud_enable_single_tunnel_mode | Enable peering with Single-Tunnel mode for cross-cloud peering. Only applies with enable_peering_over_private_network. | `bool` | `false` | no |
| cross_cloud_tunnel_count | Number of public tunnels for cross-cloud Insane Mode Encryption over Internet. Valid range: 2-20. Only for AWS-Azure peerings. | `number` | `null` (15 for HPE) | no |

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

  # Same-cloud peering configuration
  same_cloud_enable_peering_over_private_network         = false
  same_cloud_enable_insane_mode_encryption_over_internet = true
  same_cloud_enable_max_performance                      = true
  same_cloud_enable_single_tunnel_mode                   = false
  same_cloud_tunnel_count                                = 15

  # Cross-cloud peering configuration
  cross_cloud_enable_peering_over_private_network         = false
  cross_cloud_enable_insane_mode_encryption_over_internet = true
  cross_cloud_enable_max_performance                      = true
  cross_cloud_enable_single_tunnel_mode                   = false
  cross_cloud_tunnel_count                                = 15
}
```

## Notes

- HA gateways (ending with `-hagw`) are automatically excluded from peering calculations
- Same-cloud pairs are pruned from cross-cloud peering to avoid duplicate connections
- The module uses the Aviatrix controller credentials stored in AWS SSM Parameter Store
- High-Performance Encryption (HPE) is automatically detected and enabled for AWS and Azure gateways
- When `enable_insane_mode_encryption_over_internet` is set to `null`, it automatically enables for AWS-Azure peerings
- When `tunnel_count` is set to `null`, it defaults to 15 tunnels for HPE-supported peerings (AWS-Azure)
- Separate configurations allow different settings for same-cloud vs cross-cloud peering scenarios
