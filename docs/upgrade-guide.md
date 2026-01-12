# Upgrade Guide

This document provides guidance for upgrading between module versions.

## Version Compatibility

Before upgrading, check the [COMPATIBILITY.md](../COMPATIBILITY.md) for version requirements.

## Upgrading from Previous Versions

### Directory Structure Changes

If you were using the previous directory structure (`control/8/`), update your module sources:

| Old Path | New Path |
|----------|----------|
| `control/8/aws2.1` | `modules/control/aws` |
| `control/8/azure2.1` | `modules/control/azure` |
| `control/8/gcp2.1` | `modules/control/gcp` |
| `control/8/peering2.0` | `modules/control/peering` |
| `control/8/segmentation` | `modules/control/segmentation` |
| `control/8/dcf` | `modules/control/dcf` |
| `mgmt2.0` | `modules/mgmt` |
| `migration` | `modules/migration` |

### Migration Steps

1. **Update module sources** in your Terraform configurations:

   ```hcl
   # Before
   module "aws_transit" {
     source = "git::https://github.com/org/repo.git//control/8/aws2.1"
   }

   # After
   module "aws_transit" {
     source = "git::https://github.com/org/repo.git//modules/control/aws"
   }
   ```

2. **Run terraform init** to update module references:

   ```bash
   terraform init -upgrade
   ```

3. **Review the plan** before applying:

   ```bash
   terraform plan
   ```

4. **Apply changes** if the plan looks correct:

   ```bash
   terraform apply
   ```

## Provider Version Upgrades

### Aviatrix Provider

When upgrading the Aviatrix provider:

1. Check release notes for breaking changes
2. Update `required_providers` block:

   ```hcl
   terraform {
     required_providers {
       aviatrix = {
         source  = "AviatrixSystems/aviatrix"
         version = "8.1.10"  # Update version
       }
     }
   }
   ```

3. Run `terraform init -upgrade`
4. Review and apply changes

### Controller Upgrades

When upgrading your Aviatrix Controller:

1. Ensure controller and provider versions are compatible
2. Upgrade controller first, then provider
3. Run `terraform plan` to detect any drift
4. Apply any necessary configuration updates

## Breaking Changes

### Version 1.0.0

- Initial release with new directory structure
- No breaking changes from previous internal versions

## Rollback Procedures

If you encounter issues after upgrading:

1. **Revert module source** to previous path
2. **Run terraform init** to restore previous modules
3. **Apply** to restore previous state

Always maintain backups of your Terraform state before upgrading.
