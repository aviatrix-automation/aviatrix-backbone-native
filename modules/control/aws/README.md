# AWS 2.1 - Aviatrix Transit with FireNet and TGW Integration

This module deploys Aviatrix transit gateways in AWS with optional FireNet (Palo Alto firewalls), AWS Transit Gateway (TGW) integration, spoke gateways, and external device connections.

## Overview

The module provides:

- **Transit Gateways**: High-performance Aviatrix transit gateways with insane mode
- **FireNet Integration**: Optional Palo Alto Networks firewall deployment with automatic security groups
- **TGW Connectivity**: AWS Transit Gateway integration with Connect attachments and BGP peering
- **Spoke Gateways**: Aviatrix spoke gateways attached to transit
- **External Devices**: Site-to-Site VPN connections to external devices

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Transit Gateway                          │
│  - Connect attachments                                          │
│  - BGP Connect Peers (8 peers per transit)                      │
│  - Cross-account sharing support                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Aviatrix Transit Gateway                       │
│  - Insane mode enabled                                          │
│  - BGP ECMP, S2C RX balancing                                   │
│  - Transit FireNet (optional)                                   │
│  - Segmentation enabled                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   FireNet       │  │  Spoke Gateway  │  │ External Device │
│ Palo Alto VMs   │  │  Attached VPCs  │  │  IPSec/BGP      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
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
| aviatrix | Aviatrix provider for gateway and FireNet management |
| aws | AWS provider for TGW, security groups, and EC2 resources |
| aws.ssm | AWS provider for SSM parameter retrieval |
| tls | TLS provider for SSH key generation |

## Modules

| Name | Source | Version |
|------|--------|---------|
| mc-transit | terraform-aviatrix-modules/mc-transit/aviatrix | 8.0.0 |

## Resources

| Name | Type |
|------|------|
| aviatrix_firenet | resource |
| aviatrix_firewall_instance | resource |
| aviatrix_firewall_instance_association | resource |
| aviatrix_transit_external_device_conn | resource |
| aviatrix_spoke_transit_attachment | resource |
| aws_ec2_transit_gateway | resource |
| aws_ec2_transit_gateway_connect | resource |
| aws_ec2_transit_gateway_connect_peer | resource |
| aws_ec2_transit_gateway_vpc_attachment | resource |
| aws_security_group (mgmt, lan, egress) | resource |
| aws_key_pair | resource |
| tls_private_key | resource |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| aws_ssm_region | AWS region for SSM parameter retrieval | `string` | yes |
| region | AWS region for transit deployment | `string` | yes |
| transits | Map of transit gateway configurations | `map(object)` | no |
| tgws | Map of AWS Transit Gateway configurations | `map(object)` | no |
| spokes | Map of spoke gateway configurations | `map(object)` | no |
| external_devices | Map of external device connections | `map(object)` | no |

### Transit Configuration

```hcl
transits = {
  "aws-transit-prod" = {
    account                = "aws-account-name"
    cidr                   = "10.0.0.0/23"
    instance_size          = "c5n.9xlarge"
    local_as_number        = 65011
    fw_amount              = 2                    # Number of firewall instances (pairs)
    firewall_image         = "ami-xxxx"          # Palo Alto AMI
    firewall_image_version = "12.1.3-h2"
    tgw_name               = "prod"              # Optional: TGW to connect
    inspection_enabled     = false
    egress_enabled         = true
  }
}
```

### TGW Configuration

```hcl
tgws = {
  "prod" = {
    amazon_side_asn             = 64512
    transit_gateway_cidr_blocks = ["172.16.0.0/24"]
    create_tgw                  = true
    account_ids                 = ["123456789012"]  # Cross-account sharing
  }
}
```

### Spoke Configuration

```hcl
spokes = {
  "app-spoke-1" = {
    account                = "aws-account-name"
    attached               = true
    cidr                   = "10.10.0.0/16"
    insane_mode            = true
    enable_max_performance = true
    transit_key            = "aws-transit-prod"
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| mgmt_subnet_ids | Map of management subnet IDs per transit |

## Notes

- Transit gateways are deployed with insane mode for high throughput
- FireNet deploys Palo Alto firewalls in pairs (primary + HA) per transit
- TGW Connect supports up to 8 BGP peers per transit for high bandwidth
- SSH keys are auto-generated if not provided
- Security groups are automatically created for management, LAN, and egress interfaces
