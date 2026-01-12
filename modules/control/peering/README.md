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
│  - No encryption over private network                           │
│  - Max performance enabled                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Cross-Cloud Peering                           │
│  (between all primary gateways across clouds)                   │
│  - Insane mode encryption over internet                         │
│  - Max performance enabled                                      │
│  - 15 tunnel count                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aviatrix | >= 3.0 |
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

## Outputs

| Name | Description |
|------|-------------|
| same_cloud_peerings | Same-cloud transit gateway peerings created, grouped by cloud type |
| cross_cloud_peerings | Cross-cloud transit gateway peerings created with all involved gateways |
| all_primary_gateways | List of all primary transit gateways involved in peering |
| gateways_by_cloud_type | Primary transit gateways grouped by cloud type |

## Usage

```hcl
module "peering" {
  source = "git::https://github.com/org/repo.git//modules/control/peering"

  aws_ssm_region = "us-east-1"
}
```

## Notes

- HA gateways (ending with `-hagw`) are automatically excluded from peering calculations
- Same-cloud pairs are pruned from cross-cloud peering to avoid duplicate connections
- The module uses the Aviatrix controller credentials stored in AWS SSM Parameter Store
