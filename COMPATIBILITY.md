# Compatibility Matrix

This document outlines the version requirements and compatibility information for the Aviatrix multi-cloud networking modules.

## Terraform Version

| Module | Minimum Terraform Version |
|--------|---------------------------|
| All modules | >= 1.0 |

## Provider Versions

### Aviatrix Provider

| Module | Provider Version | Source |
|--------|-----------------|--------|
| aws | 8.1.1 | AviatrixSystems/aviatrix |
| azure | 8.1.1 | AviatrixSystems/aviatrix |
| gcp | 8.1.1 | AviatrixSystems/aviatrix |
| peering | 8.1.10 | AviatrixSystems/aviatrix |
| segmentation | 8.1.1 | AviatrixSystems/aviatrix |
| dcf | 8.1.1 | AviatrixSystems/aviatrix |

### Cloud Provider Versions

| Provider | Source | Recommended Version |
|----------|--------|---------------------|
| AWS | hashicorp/aws | >= 5.0 |
| Azure | hashicorp/azurerm | >= 3.0 |
| GCP | hashicorp/google | >= 5.0 |

### Additional Providers

| Provider | Version | Used By |
|----------|---------|---------|
| terracurl | 2.1.0 | segmentation |

## Aviatrix Controller Compatibility

| Module Version | Minimum Controller Version |
|----------------|---------------------------|
| 1.0.x | 8.0 |

## External Module Dependencies

| Module | Dependency | Version |
|--------|------------|---------|
| controlplane | terraform-aviatrix-modules/aws-controlplane/aviatrix | 1.0.6 |
| aws | terraform-aviatrix-modules/mc-transit | Latest |
| aws | terraform-aviatrix-modules/mc-spoke | Latest |
| azure | terraform-aviatrix-modules/mc-transit | Latest |
| azure | terraform-aviatrix-modules/mc-spoke | Latest |
| gcp | terraform-aviatrix-modules/mc-transit | Latest |
| gcp | terraform-aviatrix-modules/mc-spoke | Latest |

## Cloud Platform Requirements

### AWS
- IAM permissions for VPC, EC2, Transit Gateway operations
- AWS SSM Parameter Store access for credentials

### Azure
- Subscription with Virtual WAN support
- Service Principal with Network Contributor role

### GCP
- Project with Network Connectivity Center API enabled
- Service Account with Network Admin role

## Notes

- All modules retrieve Aviatrix credentials from AWS SSM Parameter Store
- FireNet integration requires Palo Alto Networks VM-Series licensing
- Transit Gateway Connect (AWS) requires specific instance types for BGP peering
