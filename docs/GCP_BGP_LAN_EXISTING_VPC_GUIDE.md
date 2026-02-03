# GCP BGP over LAN - Using Existing VPC and Subnets

## Overview

This guide explains how to configure Aviatrix Transit Gateways to use **existing GCP VPCs and subnets** for BGP over LAN connections instead of creating new ones.

## Feature Branch

**Branch**: `feature/gcp-bgpolan-existing-vpc`

## Two Configuration Modes

### Mode 1: Create New VPC/Subnets (Default)
The module creates dedicated VPCs and subnets for BGP LAN connectivity.

### Mode 2: Use Existing VPC/Subnets (New Feature)
The module uses your existing VPCs and subnets for BGP LAN connectivity.

---

## Mode 1: Creating New VPC/Subnets (Existing Behavior)

### Configuration Example

```hcl
module "transit" {
  source = "./modules/transit"

  project_id = "my-gcp-project"

  ncc_hubs = [
    {
      name            = "ai-1"
      create          = true                    # Creates new VPC
      preset_topology = "MESH"
    }
  ]

  transits = [
    {
      gw_name = "gcp-us-transit"
      region  = "us-east1"

      bgp_lan_subnets = {
        ai-1 = {
          cidr = "10.1.0.0/24"                  # CIDR for new subnet
        }
      }

      cloud_router_asn = 16550
      aviatrix_gw_asn  = 65511
      # ... other config
    }
  ]
}
```

### What Gets Created

- **VPC**: `bgp-lan-ai-1-vpc`
- **Subnet**: `gcp-us-transit-bgp-lan-ai-1-subnet` (10.1.0.0/24)
- **Cloud Router**: `gcp-us-transit-bgp-lan-ai-1-router` (ASN 16550)
- **Firewall Rule**: `bgp-lan-ai-1-allow-bgp` (allows TCP 179)

---

## Mode 2: Using Existing VPC/Subnets (New Feature)

### Prerequisites

Before using this mode, ensure your existing VPC has:

1. ✅ **Existing VPC** in the target region
2. ✅ **Existing Subnet** with sufficient IP space for Aviatrix BGP LAN interfaces
3. ✅ **Existing Cloud Router** with BGP configured
4. ✅ **Firewall Rules** allowing BGP traffic (TCP port 179)

### Configuration Example

```hcl
module "transit" {
  source = "./modules/transit"

  project_id = "my-gcp-project"

  ncc_hubs = [
    {
      name                 = "ai-1"
      create               = false                          # Use existing VPC
      existing_vpc_name    = "customer-shared-vpc"          # Your existing VPC name
      existing_vpc_project = "shared-vpc-project"           # Optional: defaults to project_id
      preset_topology      = "MESH"
    }
  ]

  transits = [
    {
      gw_name = "gcp-us-transit"
      region  = "us-east1"

      bgp_lan_subnets = {
        ai-1 = {
          cidr                 = "10.100.0.0/24"            # For validation
          existing_subnet_name = "existing-bgp-lan-subnet"  # Your existing subnet name
        }
      }

      cloud_router_asn = 16550
      aviatrix_gw_asn  = 65511
      # ... other config
    }
  ]
}
```

### What the Module Does

- ❌ **Does NOT create**: VPC, subnet, Cloud Router, or firewall rules
- ✅ **Uses existing**: VPC and subnet via data sources
- ✅ **Configures**: Aviatrix Transit Gateway BGP LAN interfaces on existing subnet
- ✅ **Creates**: Aviatrix-specific resources (transit gateway, BGP peering)

---

## Detailed Configuration Reference

### ncc_hubs Variable

```hcl
variable "ncc_hubs" {
  type = list(object({
    name                 = string           # Hub name (e.g., "ai-1")
    create               = optional(bool, true)  # true = create new, false = use existing
    preset_topology      = optional(string, "STAR")  # STAR or MESH

    # Only needed when create = false
    existing_vpc_name    = optional(string)  # Name of existing VPC
    existing_vpc_project = optional(string)  # Project ID (defaults to main project_id)
  }))
}
```

### bgp_lan_subnets Variable

```hcl
bgp_lan_subnets = map(object({
  cidr                 = string              # CIDR block
  existing_subnet_name = optional(string)    # Name of existing subnet (when create = false)
}))
```

---

## Example Scenarios

### Scenario 1: Single Transit with Existing VPC

```hcl
ncc_hubs = [
  {
    name              = "production-hub"
    create            = false
    existing_vpc_name = "prod-shared-vpc"
    preset_topology   = "MESH"
  }
]

transits = [
  {
    gw_name = "gcp-prod-transit"
    region  = "us-central1"

    bgp_lan_subnets = {
      production-hub = {
        cidr                 = "172.16.10.0/24"
        existing_subnet_name = "prod-aviatrix-bgp-subnet"
      }
    }

    cloud_router_asn = 64512
    aviatrix_gw_asn  = 65100
    # ...
  }
]
```

### Scenario 2: Multiple Transits, Mixed Mode

```hcl
ncc_hubs = [
  {
    name            = "hub-new"
    create          = true              # Create new VPC
    preset_topology = "MESH"
  },
  {
    name                 = "hub-existing"
    create               = false         # Use existing VPC
    existing_vpc_name    = "legacy-vpc"
    existing_vpc_project = "legacy-project"
    preset_topology      = "STAR"
  }
]

transits = [
  {
    gw_name = "gcp-us-transit"
    region  = "us-east1"

    bgp_lan_subnets = {
      hub-new = {
        cidr = "10.1.0.0/24"            # New subnet
      }
      hub-existing = {
        cidr                 = "192.168.1.0/24"  # Validation
        existing_subnet_name = "legacy-bgp-subnet"
      }
    }
    # ...
  }
]
```

### Scenario 3: Cross-Project Existing VPC

```hcl
ncc_hubs = [
  {
    name                 = "shared-services"
    create               = false
    existing_vpc_name    = "shared-services-vpc"
    existing_vpc_project = "shared-services-project-123"  # Different project
    preset_topology      = "MESH"
  }
]

transits = [
  {
    gw_name = "gcp-europe-transit"
    region  = "europe-west1"

    bgp_lan_subnets = {
      shared-services = {
        cidr                 = "10.200.0.0/24"
        existing_subnet_name = "shared-bgp-lan-subnet"
      }
    }
    # ...
  }
]
```

---

## Requirements for Existing VPC/Subnet

### 1. VPC Requirements

- **Routing Mode**: Must be `REGIONAL` (recommended) or `GLOBAL`
- **Auto-create subnets**: Should be `false` (custom subnets)
- **Project**: Can be in the same or different GCP project
- **Region**: Must match the transit gateway region

### 2. Subnet Requirements

- **IP Range**: Must have sufficient IPs for Aviatrix BGP LAN interfaces
  - Primary: 1 IP
  - HA: 1 IP
  - Total per transit: 2 IPs minimum
- **Region**: Must match the transit gateway region
- **Network**: Must belong to the specified existing VPC
- **Purpose**: Should be `PRIVATE` (not reserved for special use)

### 3. Cloud Router Requirements

- **Existing Router**: Must already exist in the VPC
- **ASN**: Must match `cloud_router_asn` in transit configuration
- **Region**: Must match the subnet region
- **BGP Sessions**: Should be configured for Aviatrix gateway IPs

### 4. Firewall Rules

Must allow:
- **Protocol**: TCP
- **Port**: 179 (BGP)
- **Source**: Subnet CIDR ranges of all transits
- **Target**: Resources with `bgp-lan` network tag (or appropriate targeting)

Example firewall rule:
```bash
gcloud compute firewall-rules create allow-bgp-lan \
  --network=customer-shared-vpc \
  --allow=tcp:179 \
  --source-ranges=10.100.0.0/24,10.101.0.0/24 \
  --target-tags=bgp-lan \
  --description="Allow BGP traffic for Aviatrix"
```

---

## Validation

The module includes validation to ensure proper configuration:

### Validation Rules

1. **When `create = false`**: `existing_vpc_name` must be provided
2. **CIDR format**: All CIDRs must be valid CIDR ranges
3. **Hub names**: All `bgp_lan_subnets` keys must match NCC hub names
4. **Topology**: Must be either "STAR" or "MESH"

### Validation Errors

```hcl
# ❌ ERROR: Missing existing_vpc_name
ncc_hubs = [{
  name   = "hub1"
  create = false
  # Missing: existing_vpc_name = "..."
}]
# Error: "When create = false, existing_vpc_name must be provided."

# ❌ ERROR: Invalid CIDR
bgp_lan_subnets = {
  hub1 = {
    cidr = "10.1.0.0/33"  # Invalid CIDR
  }
}
# Error: "All non-empty BGP LAN subnet CIDRs must be valid CIDR ranges."
```

---

## Migration Path

### Migrating from Created to Existing VPC

If you want to migrate from module-created VPCs to existing VPCs:

**Option 1: Import Existing Resources**
```bash
# Import the VPC created by the module
terraform import 'data.google_compute_network.existing_bgp_lan_vpcs["ai-1"]' bgp-lan-ai-1-vpc

# Update configuration to use existing mode
```

**Option 2: Create New Environment**
```hcl
# In a new environment, use existing mode from the start
ncc_hubs = [{
  name              = "ai-1"
  create            = false
  existing_vpc_name = "bgp-lan-ai-1-vpc"  # Previously created VPC
}]
```

---

## Troubleshooting

### Issue: "VPC not found"

**Error**:
```
Error: Error reading Network: googleapi: Error 404: The resource 'projects/.../networks/customer-vpc' was not found
```

**Solution**:
- Verify `existing_vpc_name` is correct
- Check `existing_vpc_project` if VPC is in a different project
- Ensure the service account has permissions to read the VPC

### Issue: "Subnet not found"

**Error**:
```
Error: Error reading Subnetwork: googleapi: Error 404: The resource 'projects/.../subnetworks/customer-subnet' was not found
```

**Solution**:
- Verify `existing_subnet_name` is correct
- Check that subnet exists in the correct region
- Ensure subnet belongs to the specified VPC

### Issue: "Insufficient IPs"

**Error**:
```
Error: Error creating BGP LAN interface: Insufficient IP addresses in subnet
```

**Solution**:
- Ensure subnet has at least 2 available IPs per transit gateway
- Check for IP address conflicts
- Consider expanding the subnet CIDR range

### Issue: "BGP session not establishing"

**Symptoms**: BGP session shows "Active" but not "Established"

**Solution**:
1. Verify firewall rules allow TCP 179
2. Check Cloud Router ASN matches configuration
3. Verify Aviatrix gateway IPs are reachable
4. Check Cloud Router has correct BGP peer configuration

---

## Best Practices

1. **Use Dedicated Subnets**: Create dedicated subnets for BGP LAN (don't share with workloads)
2. **Document IP Ranges**: Maintain documentation of IP allocations
3. **Test Connectivity**: Verify BGP sessions establish after configuration
4. **Monitor Routes**: Check that routes are being advertised/received correctly
5. **Version Control**: Keep VPC/subnet configurations in version control
6. **IAM Permissions**: Ensure proper cross-project permissions when using shared VPCs

---

## Summary

| Feature | Create Mode (`create = true`) | Existing Mode (`create = false`) |
|---------|-------------------------------|----------------------------------|
| **VPC** | ✅ Module creates | ❌ Must exist, module looks up |
| **Subnet** | ✅ Module creates | ❌ Must exist, module looks up |
| **Cloud Router** | ✅ Module creates | ❌ Must exist (not managed) |
| **Firewall Rules** | ✅ Module creates | ❌ Must exist (not managed) |
| **BGP LAN Interfaces** | ✅ Module configures | ✅ Module configures |
| **Use Case** | Greenfield deployments | Existing VPC environments |

---

## Support

For issues or questions:
- **Feature Branch**: `feature/gcp-bgpolan-existing-vpc`
- **Testing**: Test with `create = true` first (existing behavior) before using `create = false`
- **Validation**: Run `terraform validate` to catch configuration errors early

---

**Last Updated**: 2026-02-03
**Feature Status**: ✅ Implemented, ⏳ Testing in progress
