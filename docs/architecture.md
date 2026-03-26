# Architecture Overview

This document describes the architecture of the Aviatrix multi-cloud networking modules.

## Module Hierarchy

```
modules/
├── control/              # Transit and networking modules
│   ├── aws/              # AWS Transit with TGW and FireNet
│   │   ├── main.tf           # Passthrough module call
│   │   ├── variables.tf      # Public API
│   │   ├── outputs.tf        # Public outputs
│   │   └── modules/transit/  # Implementation
│   ├── azure/            # Azure Transit with Virtual WAN
│   │   └── (same structure)
│   ├── gcp/              # GCP Transit with NCC
│   │   └── (same structure)
│   ├── peering/          # Transit Gateway Peering
│   ├── segmentation/     # Network Segmentation Domains
│   └── dcf/              # Distributed Cloud Firewall
├── mgmt/                 # Aviatrix Controller Deployment
└── migration/            # Migration utilities
```

## Two-Level Module Composition

Each cloud module uses a **wrapper/submodule** pattern:

```
modules/control/{cloud}/          ← Public API (consumer-facing)
  main.tf                         ← module "transit" { source = "./modules/transit", ... }
  variables.tf                    ← Re-exports all submodule variables
  outputs.tf                      ← Re-exports all submodule outputs

modules/control/{cloud}/modules/transit/  ← Implementation (internal)
  provider.tf                     ← Provider configuration (SSM-based auth)
  main.tf                         ← Resource definitions
  variables.tf                    ← Variable declarations with validations
  output.tf                       ← Output declarations
  locals.tf                       ← Data transformations
```

**Why two levels?**
- The outer module is the **stable public API** consumers reference via `source = "git::...?ref=v0.8.0"`
- The inner submodule contains all implementation details, provider configuration, and can evolve independently
- Provider blocks (Aviatrix, cloud-specific) live in the submodule, keeping the public API clean

## Deployment Flow

```
┌──────────────────┐
│   Control Plane  │  Step 1: Deploy Aviatrix Controller
│   (modules/mgmt) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Transit Gateways │  Step 2: Deploy Transit in each cloud
│  (control/aws,   │
│  azure, gcp)     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│     Peering      │  Step 3: Establish cross-cloud peering
│ (control/peering)│
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   Segmentation   │  Step 4: Configure network domains
│(control/segment) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│       DCF        │  Step 5: Apply firewall policies
│  (control/dcf)   │
└──────────────────┘
```

## Cloud-Specific Integrations

### AWS
- **Transit Gateway (TGW)**: Native AWS TGW Connect with up to 8 BGP peers per transit
- **FireNet**: Palo Alto VM-Series firewall integration with auto-generated security groups
- **Spoke Attachments**: VPC attachments via Aviatrix spoke gateways
- **Learned CIDR Approval**: Per-TGW connection learned route filtering

### Azure
- **Virtual WAN**: Native Azure vWAN hub integration with BGP peering
- **FireNet**: Palo Alto VM-Series with File Share or Panorama bootstrap
- **Spoke Gateways**: BGP-enabled spoke gateways with vWAN connectivity
- **VNET Integration**: Create new or connect existing VNETs to vWAN hubs
- **Learned CIDR Approval**: Per-vWAN connection learned route filtering

### GCP
- **Network Connectivity Center (NCC)**: Native NCC hub integration (STAR or MESH topology)
- **Cloud Router**: BGP-over-LAN peering with Cloud Routers via VLAN attachments
- **FireNet**: Palo Alto VM-Series with GCS bucket bootstrap and optional static IP assignment
- **External Load Balancer**: Global Application LB with PBF enforce-symmetric-return for inbound traffic through firewalls
- **Learned CIDR Approval**: Per-NCC hub connection learned route filtering

## Credential Management

All modules retrieve Aviatrix Controller credentials from AWS SSM Parameter Store:

```
AWS SSM Parameters:
├── /aviatrix/controller/ip
├── /aviatrix/controller/username
└── /aviatrix/controller/password
```

The `aws_ssm_region` variable tells each module which AWS region to query for these parameters. This is the only cross-cloud dependency.

## Network Segmentation

Network segmentation is implemented using Aviatrix Network Domains:

```
┌─────────────────────────────────────────────┐
│              Transit Network                │
├─────────────┬─────────────┬─────────────────┤
│ Production  │ Development │   Shared Svcs   │
│   Domain    │   Domain    │     Domain      │
└─────────────┴─────────────┴─────────────────┘
```

Connection policies control traffic flow between domains. The segmentation module auto-infers domain associations from naming conventions (`external-{domain}-*` for transit connections, domain name substring matching for spoke gateways).

## Distributed Cloud Firewall

The DCF module provides micro-segmentation with smart groups and firewall policies:

- **Smart Groups**: Match by CIDR, VM tags, explicit S2C connections, or domain-resolved connections
- **Policies**: Per-policy control of action, protocol, port ranges, logging, and watch mode
- **Default Action**: Configurable PERMIT or DENY for unmatched traffic

## Versioning and Release

Releases are automated via [release-please](https://github.com/googleapis/release-please) using [Conventional Commits](https://www.conventionalcommits.org/). Consumers pin to release tags for stability:

```hcl
source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/aws?ref=v0.8.0"
```
