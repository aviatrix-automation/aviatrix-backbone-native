# Architecture Overview

This document describes the architecture of the Aviatrix multi-cloud networking modules.

## Module Hierarchy

```
modules/
├── control/              # Transit and networking modules
│   ├── aws/              # AWS Transit with TGW and FireNet
│   ├── azure/            # Azure Transit with Virtual WAN
│   ├── gcp/              # GCP Transit with NCC
│   ├── peering/          # Transit Gateway Peering
│   ├── segmentation/     # Network Segmentation Domains
│   └── dcf/              # Distributed Cloud Firewall
├── mgmt/                 # Aviatrix Controller Deployment
└── migration/            # Migration utilities
```

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
- **Transit Gateway (TGW)**: Native AWS TGW Connect with BGP peering
- **FireNet**: Palo Alto VM-Series firewall integration
- **Spoke Attachments**: VPC attachments via Aviatrix spoke gateways

### Azure
- **Virtual WAN**: Native Azure vWAN hub integration
- **BGP Peering**: Direct BGP sessions with vWAN hubs
- **VNET Integration**: Spoke VNET attachments

### GCP
- **Network Connectivity Center (NCC)**: Native NCC hub integration
- **Cloud Router**: BGP peering with Cloud Routers
- **VPC Spokes**: GCP VPC attachments

## Credential Management

All modules retrieve Aviatrix Controller credentials from AWS SSM Parameter Store:

```
AWS SSM Parameters:
├── /aviatrix/controller/ip
├── /aviatrix/controller/username
└── /aviatrix/controller/password
```

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

Connection policies control traffic flow between domains.
