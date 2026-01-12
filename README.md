# Aviatrix Multi-Cloud Networking Modules

Terraform modules for deploying and managing multi-cloud network infrastructure using Aviatrix.

## Repository Structure

```
.
├── modules/
│   ├── control/             # Transit and networking modules
│   │   ├── aws/             # AWS Transit with TGW and FireNet
│   │   ├── azure/           # Azure Transit with Virtual WAN
│   │   ├── gcp/             # GCP Transit with NCC
│   │   ├── peering/         # Transit Gateway Peering
│   │   ├── segmentation/    # Network Segmentation Domains
│   │   └── dcf/             # Distributed Cloud Firewall
│   ├── mgmt/                # Aviatrix Controller Deployment
│   └── migration/           # Migration utilities
├── examples/                # Usage examples
├── docs/                    # Documentation
└── tests/                   # Test infrastructure
```

## Quick Start

See [docs/getting-started.md](docs/getting-started.md) for a complete guide.

## Prerequisites

- **Terraform:** >= 1.0
- **Aviatrix Controller:** 8.0+
- **Providers:**
  - Aviatrix: 8.1.x
  - AWS: >= 5.0
  - Azure: >= 3.0
  - Google: >= 5.0

See [COMPATIBILITY.md](COMPATIBILITY.md) for detailed version requirements.

## Modules

| Module | Description | Cloud |
|--------|-------------|-------|
| [control/aws](modules/control/aws/) | AWS Transit with TGW and FireNet integration | AWS |
| [control/azure](modules/control/azure/) | Azure Transit with Virtual WAN integration | Azure |
| [control/gcp](modules/control/gcp/) | GCP Transit with Network Connectivity Center | GCP |
| [control/peering](modules/control/peering/) | Full-mesh transit gateway peering | Multi-cloud |
| [control/segmentation](modules/control/segmentation/) | Network segmentation domains | Multi-cloud |
| [control/dcf](modules/control/dcf/) | Distributed cloud firewall policies | Multi-cloud |
| [mgmt](modules/mgmt/) | Aviatrix Controller deployment | AWS |
| [migration](modules/migration/) | Migration utilities | Multi-cloud |

## Compatibility Matrix

| Module | AWS | Azure | GCP | Aviatrix Version |
|--------|-----|-------|-----|------------------|
| Transit GW | ✅ | ✅ | ✅ | 8.x |
| Peering | ✅ | ✅ | ✅ | 8.x |
| Segmentation | ✅ | ✅ | ✅ | 8.x |
| DCF | ✅ | ✅ | ✅ | 8.x |

## Implementation Flow

```
┌─────────────────────┐
│  Deploy Controller  │  (modules/mgmt)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Deploy Transit GWs  │  (modules/control/aws, azure, gcp)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Configure Peering │  (modules/control/peering)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Setup Segmentation │  (modules/control/segmentation)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    Apply DCF Rules  │  (modules/control/dcf)
└─────────────────────┘
```

## Examples

- [AWS Basic Transit](examples/aws-basic/)
- [Azure Basic Transit](examples/azure-basic/)
- [GCP Basic Transit](examples/gcp-basic/)
- [Multi-Cloud Deployment](examples/multi-cloud/)

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Getting Started](docs/getting-started.md)
- [Upgrade Guide](docs/upgrade-guide.md)
- [Compatibility Matrix](COMPATIBILITY.md)
- [Changelog](CHANGELOG.md)
