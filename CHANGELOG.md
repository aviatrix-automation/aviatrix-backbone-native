# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-01-20)


### Features

* add attach_firewall variable to control firewall association ([9fa08e7](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/9fa08e70be78346a78f8c69453b47c1ee1d0c9c2))
* add GitHub Actions workflows for Terraform validation and security scanning ([d6a6154](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/d6a6154d93f620a71719b711b580576d1f3336c5))
* add Release Please automation for changelog and releases ([928fad4](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/928fad476e759521f1a9c7541758d3f02afecebd))


### Bug Fixes

* resolve Terraform validation error for panorama_config variable ([9ccc1b2](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/9ccc1b28cb8abc951e43ce2fc34a016da581b9b1))
* update GitHub Actions to use only allowed actions ([67f1fb0](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/67f1fb0e46f16b557f505e02408b3ee52e27eebb))


### Miscellaneous

* make Terraform validation workflow non-blocking ([c956e5c](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/c956e5c8c60e475556dceb4ce501725652f44ac5))
* remove .terraform.lock.hcl and update .gitignore ([#4](https://github.com/aviatrix-automation/aviatrix-backbone-native/issues/4)) ([28497ed](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/28497edecfa8677777554c770c039c5d4f68908c))
* remove customer-specific reference from example configuration ([e5e9293](https://github.com/aviatrix-automation/aviatrix-backbone-native/commit/e5e929340f44b36ff769f33fb0606747b35fd077))

## [Unreleased]

### Changed
- Reorganized repository structure for better maintainability
- Renamed `control/8/` to `modules/` with simplified folder names
- Added `examples/` directory with usage examples
- Added `docs/` directory for detailed documentation

## [1.0.0] - 2025-12-22

### Added
- Initial release of Aviatrix multi-cloud networking modules
- AWS transit module with FireNet and TGW integration
- Azure transit module with Virtual WAN integration
- GCP transit module with Network Connectivity Center support
- Transit gateway peering module for multi-cloud connectivity
- Network segmentation module with domain management
- Distributed cloud firewall (DCF) module
- Control plane deployment module for Aviatrix controller
- Comprehensive test suite with pytest integration
- GitHub Actions workflows for security scanning and linting

### Security
- Integrated Checkov and tfsec security scanning
- Added `.checkov.yaml` configuration for Terraform security checks
