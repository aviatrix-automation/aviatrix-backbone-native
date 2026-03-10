# Contributing to aviatrix-backbone-native

## Module Consumption

Each cloud module is consumable from a versioned Git source:

```hcl
module "aws_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/aws?ref=v0.8.0"

  aws_ssm_region = "us-east-1"
  region         = "us-east-1"
  transits       = var.transits
  tgws           = var.tgws
}
```

Available modules:
- `modules/control/aws` - AWS Transit + TGW + FireNet
- `modules/control/azure` - Azure Transit + vWAN + FireNet
- `modules/control/gcp` - GCP Transit + NCC + FireNet
- `modules/control/peering` - Multi-cloud transit peering
- `modules/control/segmentation` - Network domain segmentation
- `modules/control/dcf` - Distributed Cloud Firewall
- `modules/mgmt` - Aviatrix Controller deployment

Pin to a release tag (e.g., `?ref=v0.8.0`) for stability. See `examples/` for full configuration samples.

## Development Setup

### Prerequisites
- Terraform >= 1.3
- [pre-commit](https://pre-commit.com/)
- [tflint](https://github.com/terraform-linters/tflint)

### Getting Started

```bash
# Install pre-commit hooks
pre-commit install

# Format Terraform
make fmt-terraform

# Lint
make lint

# Run security scans
make lint-security
```

### Module Structure

Each cloud module follows a two-level composition pattern:

```
modules/control/{cloud}/
  main.tf          # Passthrough to submodule
  variables.tf     # Public interface (re-exports submodule variables)
  outputs.tf       # Public outputs (re-exports submodule outputs)
  modules/transit/ # Implementation (providers, resources, locals)
```

The outer module (`modules/control/{cloud}/`) is the public API consumers use. The inner submodule (`modules/transit/`) contains all implementation details including provider configuration and resource definitions.

### Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/) with [release-please](https://github.com/googleapis/release-please) for automated versioning:

- `feat:` - New features (bumps minor version)
- `fix:` - Bug fixes (bumps patch version)
- `feat!:` or `BREAKING CHANGE:` - Breaking changes (bumps major version)
- `chore:`, `docs:`, `refactor:`, `test:`, `ci:` - No version bump

### Pull Request Process

1. Create a feature branch from `main`
2. Make changes following the module structure above
3. Ensure `terraform fmt`, `terraform validate`, and `tflint` pass
4. Submit PR - CI will run validation, linting, and security scans
5. Get review from CODEOWNERS for affected modules
6. Squash merge to `main` - release-please will handle versioning
