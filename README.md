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
├── examples/                # Usage examples and tfvars templates
├── docs/                    # Documentation
└── tests/                   # Test infrastructure
```

## Quick Start

### Module Consumption

Each module is consumable from a versioned Git source:

```hcl
module "aws_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/aws?ref=v0.8.0"

  aws_ssm_region = "us-east-1"
  region         = "us-east-1"
  transits       = var.transits
  tgws           = var.tgws
}
```

Pin to a release tag (e.g., `?ref=v0.8.0`) for stability. See [examples/](examples/) for full configuration samples and [docs/getting-started.md](docs/getting-started.md) for a complete guide.

## Prerequisites

- **Terraform:** >= 1.3
- **Aviatrix Controller:** 8.x
- **Providers:**
  - Aviatrix: ~> 8.2
  - AWS: ~> 5.0
  - Azure: ~> 3.0
  - Google: ~> 5.0

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

## Module Composition

Each cloud module follows a two-level composition pattern:

```
modules/control/{cloud}/
  main.tf          # Passthrough to submodule
  variables.tf     # Public interface
  outputs.tf       # Public outputs
  modules/transit/ # Implementation (providers, resources, locals)
```

The outer module is the public API consumers use via `source = "git::..."`. The inner submodule contains all implementation details including provider configuration, resource definitions, and locals.

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

Each cloud module has a consumption example and a `.tfvars.example` template:

- [AWS Example](examples/aws/) — `main.tf` + `aws.tfvars.example`
- [Azure Example](examples/azure/) — `main.tf` + `azure.tfvars.example`
- [GCP Example](examples/gcp/) — `main.tf` + `gcp.tfvars.example`

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Getting Started](docs/getting-started.md)
- [Use Cases](USE_CASES.md)
- [Contributing](CONTRIBUTING.md)
- [Compatibility Matrix](COMPATIBILITY.md)
- [Changelog](CHANGELOG.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for module consumption patterns, development setup, and pull request process.

## Releases

This project uses [release-please](https://github.com/googleapis/release-please) with [Conventional Commits](https://www.conventionalcommits.org/) for automated semantic versioning. See [CONTRIBUTING.md](CONTRIBUTING.md) for commit conventions.
