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
- **Transit Domain Associations**: Auto-associates external connections (Site2Cloud BGP tunnels) to domains based on naming convention
- **Spoke Domain Associations**: Auto-associates Azure spoke gateways to domains based on gateway naming convention

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
│  - External connections with "external-" prefix                 │
│  - BGP-enabled Site2Cloud tunnels on AWS/GCP transits           │
│                                                                 │
│  Spoke Associations:                                            │
│  - Azure spoke gateways (cloud_type == 8)                       │
│  - Matched by domain name in gateway name                       │
└─────────────────────────────────────────────────────────────────┘
```

## Domain Inference Logic

### Transit Connections
- Connections with names starting with `external-` are analyzed
- Domain is inferred by matching domain names within the connection name
- Only BGP-enabled Site2Cloud tunnels on AWS (cloud_type=1) or GCP (cloud_type=4) are associated

### Spoke Gateways
- Azure spoke gateways (cloud_type=8) are analyzed
- Domain is inferred by matching domain name segments in the gateway name
- HA gateways (ending with `-hagw`) are excluded

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

## Outputs

No outputs.

## Usage

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

## Notes

- The module uses terracurl to fetch Site2Cloud connections via the Aviatrix API
- Aviatrix controller credentials are retrieved from AWS SSM Parameter Store
- Domain names are matched in descending order by length to ensure longer, more specific names match first
- Only primary gateways are associated (HA gateways are excluded)
