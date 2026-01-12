# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
