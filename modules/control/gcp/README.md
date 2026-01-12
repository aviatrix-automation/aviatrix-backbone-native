# GCP 2.1 - Aviatrix Transit with NCC Integration

This module deploys Aviatrix transit gateways in GCP with Network Connectivity Center (NCC) hub integration, optional Palo Alto firewall deployment, and spoke VPC connectivity.

## Overview

The module provides:

- **Transit Gateways**: High-performance Aviatrix transit gateways with BGP LAN interfaces
- **NCC Hubs**: Google Network Connectivity Center hubs with STAR or MESH topology
- **Cloud Router Integration**: BGP peering between Aviatrix gateways and NCC hubs
- **FireNet Integration**: Optional Palo Alto Networks firewall deployment
- **Spoke Connectivity**: VPC spoke attachment to NCC hubs

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Network Connectivity Center Hub                  │
│  - STAR topology (center/edge groups)                           │
│  - MESH topology (default group)                                │
│  - Auto-accept for projects                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               │               ▼
┌─────────────────┐           │    ┌─────────────────┐
│  Cloud Router   │           │    │  Spoke VPCs     │
│  BGP Peering    │           │    │  (linked_vpc)   │
└─────────────────┘           │    └─────────────────┘
              │               │
              ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Aviatrix Transit Gateway                       │
│  - BGP LAN interfaces per NCC hub                               │
│  - Router Appliance spoke in NCC                                │
│  - HA gateway support                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FireNet (Optional)                           │
│  - Palo Alto VM-Series                                          │
│  - Bootstrap from GCS bucket                                    │
│  - Primary + HA deployment                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aviatrix | >= 3.0 |
| google | >= 4.0 |
| aws | >= 4.0 |

## Providers

| Name | Description |
|------|-------------|
| aviatrix | Aviatrix provider for gateway and FireNet management |
| google | GCP provider for NCC, VPCs, and compute resources |
| aws.ssm | AWS provider for SSM parameter retrieval |

## Modules

| Name | Source | Version |
|------|--------|---------|
| mc_transit | terraform-aviatrix-modules/mc-transit/aviatrix | 8.0.0 |

## Resources

| Name | Type |
|------|------|
| google_network_connectivity_hub | resource |
| google_network_connectivity_group (center, edge, default) | resource |
| google_network_connectivity_spoke (router appliance, VPC) | resource |
| google_compute_network (BGP LAN VPCs) | resource |
| google_compute_subnetwork (BGP LAN subnets) | resource |
| google_compute_router | resource |
| google_compute_router_interface | resource |
| google_compute_router_peer | resource |
| google_compute_firewall | resource |
| aviatrix_firenet | resource |
| aviatrix_firewall_instance | resource |
| aviatrix_transit_external_device_conn | resource |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| aws_ssm_region | AWS region for SSM parameter retrieval | `string` | yes |
| project_id | GCP project ID for NCC hubs and bootstrap storage | `string` | yes |
| ncc_hubs | List of NCC hubs to create | `list(object)` | no |
| transits | List of transit gateway configurations | `list(object)` | yes |
| spokes | List of spoke VPC configurations | `list(object)` | no |

### NCC Hub Configuration

```hcl
ncc_hubs = [
  { name = "production", create = true, preset_topology = "STAR" },
  { name = "development", create = true, preset_topology = "MESH" },
]
```

### Transit Configuration

```hcl
transits = [
  {
    access_account_name = "gcp-account"
    service_account     = "controller@project.iam.gserviceaccount.com"
    gw_name             = "gcp-us-transit"
    project_id          = "my-project"
    region              = "us-east1"
    zone                = "us-east1-b"
    ha_zone             = "us-east1-c"
    name                = "us-transit"
    vpc_cidr            = "10.1.240.0/24"
    lan_cidr            = "10.1.241.0/24"
    mgmt_cidr           = "10.1.242.0/24"
    egress_cidr         = "10.1.243.0/24"
    gw_size             = "n4-highcpu-8"
    bgp_lan_subnets = {
      production = "10.1.0.0/24"   # Key must match NCC hub name
    }
    cloud_router_asn = 16550
    aviatrix_gw_asn  = 65511
    fw_amount        = 2
    firewall_image   = "vmseries-flex-byol"
    files = {
      "bootstrap/init-cfg.txt"  = "config/init-cfg.txt"
      "bootstrap/bootstrap.xml" = "config/bootstrap.xml"
    }
  }
]
```

### Spoke Configuration

```hcl
spokes = [
  {
    vpc_name   = "app-vpc"
    project_id = "app-project"
    ncc_hub    = "production"
  }
]
```

## Outputs

No outputs currently defined.

## Notes

- Transit gateways require instance types with at least 5 network interfaces (e.g., n4-highcpu-8)
- BGP LAN subnet keys must match NCC hub names
- Cloud Router ASN must be 16550 or in the private range (64512-65534)
- Aviatrix gateway ASN must differ from Cloud Router ASN
- STAR topology uses center (transits) and edge (spokes) groups
- MESH topology uses a single default group for all spokes
- Firewall bootstrap files are stored in GCS buckets
