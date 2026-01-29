# AWS IPsec Tunnel Implementation Guide

## Overview

This document provides a comprehensive step-by-step guide for the IPsec tunnel implementation in the AWS Transit module, allowing connections to external devices via IPsec VPN.

## Architecture

The implementation allows Aviatrix Transit Gateways in AWS to establish IPsec VPN tunnels to:
- On-premises data centers
- Third-party VPN gateways
- Other cloud providers (Oracle, IBM, etc.)
- Branch offices with VPN devices

## Implementation Steps

### Step 1: Define External Device Variable Structure

**File**: `modules/control/aws/modules/transit/variables.tf`

Added `external_devices` variable to accept external device configurations:

```hcl
variable "external_devices" {
  description = "Map of external devices to connect to Aviatrix Transit Gateways."
  type        = map(object({
    # Basic connection parameters
    transit_key               = string  # Which transit gateway to use
    connection_name           = string  # Name for the IPsec connection
    remote_gateway_ip         = string  # Public IP of remote VPN gateway

    # BGP configuration
    bgp_enabled               = bool
    bgp_remote_asn            = optional(string)  # Remote BGP ASN

    # Tunnel IP addressing
    local_tunnel_cidr         = optional(string)  # e.g., "169.254.1.0/30"
    remote_tunnel_cidr        = optional(string)  # e.g., "169.254.1.4/30"

    # High Availability
    ha_enabled                = bool
    backup_remote_gateway_ip  = optional(string)
    backup_local_tunnel_cidr  = optional(string)
    backup_remote_tunnel_cidr = optional(string)

    # Security parameters
    enable_ikev2              = optional(bool)
    inspected_by_firenet      = bool  # Enable FireNet inspection

    # Custom IPsec algorithm parameters
    custom_algorithms         = optional(bool, false)
    pre_shared_key            = optional(string)  # Customer-provided PSK
    phase_1_authentication    = optional(string)  # SHA-1, SHA-256, etc.
    phase_1_dh_groups         = optional(string)  # DH groups: 1, 2, 5, 14-21
    phase_1_encryption        = optional(string)  # AES-256-CBC, etc.
    phase_2_authentication    = optional(string)  # HMAC-SHA-256, etc.
    phase_2_dh_groups         = optional(string)
    phase_2_encryption        = optional(string)
    phase1_local_identifier   = optional(string)
  }))
  default = {}
}
```

**Key Design Decisions**:
- Map structure allows multiple external devices with unique keys
- All advanced features are optional with sensible defaults
- Supports both BGP (dynamic routing) and static routing
- HA support with backup tunnels
- FireNet integration for traffic inspection
- Custom IPsec algorithms for compliance requirements

### Step 2: Transform Input to Local Variables

**File**: `modules/control/aws/modules/transit/main.tf` (Lines 83-101)

Created `local.external_device_pairs` to transform input variables:

```hcl
locals {
  external_device_pairs = {
    for k, v in var.external_devices : k => {
      # Core parameters
      transit_key               = v.transit_key
      connection_name           = v.connection_name
      pair_key                  = "${v.transit_key}.${v.connection_name}"
      remote_gateway_ip         = v.remote_gateway_ip

      # BGP configuration
      bgp_enabled               = v.bgp_enabled
      bgp_remote_asn            = v.bgp_enabled ? v.bgp_remote_asn : null
      backup_bgp_remote_as_num  = v.ha_enabled ? v.bgp_remote_asn : null

      # Tunnel addressing
      local_tunnel_cidr         = v.local_tunnel_cidr
      remote_tunnel_cidr        = v.remote_tunnel_cidr
      ha_enabled                = v.ha_enabled
      backup_remote_gateway_ip  = v.ha_enabled ? v.backup_remote_gateway_ip : null
      backup_local_tunnel_cidr  = v.ha_enabled ? v.backup_local_tunnel_cidr : null
      backup_remote_tunnel_cidr = v.ha_enabled ? v.backup_remote_tunnel_cidr : null

      # Security
      enable_ikev2              = v.enable_ikev2
      inspected_by_firenet      = v.inspected_by_firenet

      # Custom IPsec algorithm parameters
      custom_algorithms         = v.custom_algorithms
      pre_shared_key            = v.pre_shared_key
      phase_1_authentication    = v.phase_1_authentication
      phase_1_dh_groups         = v.phase_1_dh_groups
      phase_1_encryption        = v.phase_1_encryption
      phase_2_authentication    = v.phase_2_authentication
      phase_2_dh_groups         = v.phase_2_dh_groups
      phase_2_encryption        = v.phase_2_encryption
      phase1_local_identifier   = v.phase1_local_identifier
    }
  }
}
```

**Purpose**:
- Normalizes input structure
- Handles conditional logic (BGP, HA, custom algorithms)
- Creates unique `pair_key` for resource identification
- Simplifies resource configuration

### Step 3: Create FireNet Inspection Policy Logic

**File**: `modules/control/aws/modules/transit/main.tf` (Lines 103-109)

Added inspection policy generation for external devices:

```hcl
locals {
  external_inspection_policies = [
    for k, v in local.external_device_pairs : {
      transit_key     = v.transit_key
      connection_name = v.connection_name
      pair_key        = v.pair_key
    } if v.inspected_by_firenet && lookup(var.transits[v.transit_key], "fw_amount", 0) > 0
  ]
}
```

**Purpose**:
- Automatically creates inspection policies when `inspected_by_firenet = true`
- Validates that FireNet is deployed (`fw_amount > 0`)
- Enables traffic inspection through Palo Alto VM-Series firewalls

### Step 4: Create External Device Connection Resource

**File**: `modules/control/aws/modules/transit/main.tf` (Lines 858-889)

Implemented the main IPsec tunnel resource:

```hcl
resource "aviatrix_transit_external_device_conn" "external_device" {
  for_each = local.external_device_pairs

  # VPC and Gateway identification
  vpc_id          = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name = each.value.connection_name
  gw_name         = module.mc-transit[each.value.transit_key].transit_gateway.gw_name

  # Remote gateway configuration
  remote_gateway_ip        = each.value.remote_gateway_ip
  backup_remote_gateway_ip = each.value.ha_enabled ? each.value.backup_remote_gateway_ip : null
  backup_bgp_remote_as_num = each.value.ha_enabled ? each.value.bgp_remote_asn : null

  # Connection type and routing
  connection_type  = each.value.bgp_enabled ? "bgp" : "static"
  bgp_local_as_num = each.value.bgp_enabled ? module.mc-transit[each.value.transit_key].transit_gateway.local_as_number : null
  bgp_remote_as_num = each.value.bgp_enabled ? each.value.bgp_remote_asn : null

  # Tunnel protocol
  tunnel_protocol = "IPsec"
  direct_connect  = false

  # High Availability
  ha_enabled                = each.value.ha_enabled
  local_tunnel_cidr         = each.value.local_tunnel_cidr
  remote_tunnel_cidr        = each.value.remote_tunnel_cidr
  backup_local_tunnel_cidr  = each.value.ha_enabled ? each.value.backup_local_tunnel_cidr : null
  backup_remote_tunnel_cidr = each.value.ha_enabled ? each.value.backup_remote_tunnel_cidr : null

  # IKE version
  enable_ikev2 = each.value.enable_ikev2 != null ? each.value.enable_ikev2 : false

  # Custom IPsec algorithm support - only set when custom_algorithms is true
  custom_algorithms      = each.value.custom_algorithms
  pre_shared_key         = each.value.custom_algorithms ? each.value.pre_shared_key : null
  phase_1_authentication = each.value.custom_algorithms ? each.value.phase_1_authentication : null
  phase_1_dh_groups      = each.value.custom_algorithms ? each.value.phase_1_dh_groups : null
  phase_1_encryption     = each.value.custom_algorithms ? each.value.phase_1_encryption : null
  phase_2_authentication = each.value.custom_algorithms ? each.value.phase_2_authentication : null
  phase_2_dh_groups      = each.value.custom_algorithms ? each.value.phase_2_dh_groups : null
  phase_2_encryption     = each.value.custom_algorithms ? each.value.phase_2_encryption : null
  phase1_local_identifier = each.value.custom_algorithms ? each.value.phase1_local_identifier : null

  depends_on = [module.mc-transit]
}
```

**Key Features**:
- Uses `for_each` to create multiple connections
- Conditional parameters based on BGP, HA, and custom algorithms
- References transit gateway outputs dynamically
- Proper dependency management

### Step 5: Integrate with FireNet Inspection

**File**: `modules/control/aws/modules/transit/main.tf` (Lines 820-846)

Updated FireNet inspection policy resource:

```hcl
resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for p in concat(local.inspection_policies, local.external_inspection_policies) :
    p.pair_key => p
    if lookup(
      { for k, v in var.transits : local.stripped_names[k] => v.inspection_enabled },
      p.transit_key,
      false
    )
  }

  transit_firenet_gateway_name = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_firenet.firenet,
    aviatrix_transit_external_device_conn.external_device,
    # ... other external connections
  ]
}
```

**Purpose**:
- Combines TGW Connect and external device inspection policies
- Creates FireNet policy with `SITE2CLOUD:` prefix
- Ensures proper resource creation order

## Usage Examples

### Example 1: Basic BGP Connection

```hcl
module "aws_transit" {
  source = "./modules/control/aws/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "onprem-datacenter-1" = {
      transit_key         = "aws-transit-east"
      connection_name     = "external-onprem-dc1"
      remote_gateway_ip   = "203.0.113.10"
      bgp_enabled         = true
      bgp_remote_asn      = "65001"
      local_tunnel_cidr   = "169.254.1.0/30"
      remote_tunnel_cidr  = "169.254.1.4/30"
      ha_enabled          = false
      enable_ikev2        = true
      inspected_by_firenet = false
    }
  }
}
```

### Example 2: HA Connection with FireNet Inspection

```hcl
external_devices = {
  "branch-office-london" = {
    transit_key               = "aws-transit-west"
    connection_name           = "external-branch-london"
    remote_gateway_ip         = "198.51.100.20"
    bgp_enabled               = true
    bgp_remote_asn            = "65002"
    local_tunnel_cidr         = "169.254.2.0/30"
    remote_tunnel_cidr        = "169.254.2.4/30"
    ha_enabled                = true
    backup_remote_gateway_ip  = "198.51.100.21"
    backup_local_tunnel_cidr  = "169.254.2.8/30"
    backup_remote_tunnel_cidr = "169.254.2.12/30"
    enable_ikev2              = true
    inspected_by_firenet      = true  # Traffic inspected by FireNet
  }
}
```

### Example 3: Custom IPsec Algorithms

```hcl
external_devices = {
  "customer-datacenter" = {
    transit_key         = "aws-transit-east"
    connection_name     = "external-customer-dc1"
    remote_gateway_ip   = "192.0.2.50"
    bgp_enabled         = true
    bgp_remote_asn      = "65003"
    local_tunnel_cidr   = "169.254.3.0/30"
    remote_tunnel_cidr  = "169.254.3.4/30"
    ha_enabled          = false
    enable_ikev2        = true
    inspected_by_firenet = false

    # Custom IPsec configuration
    custom_algorithms      = true
    pre_shared_key         = "MySecurePassword123!"
    phase_1_authentication = "SHA-256"
    phase_1_dh_groups      = "14"
    phase_1_encryption     = "AES-256-CBC"
    phase_2_authentication = "HMAC-SHA-256"
    phase_2_dh_groups      = "14"
    phase_2_encryption     = "AES-256-CBC"
  }
}
```

### Example 4: Static Routing Connection

```hcl
external_devices = {
  "partner-network" = {
    transit_key         = "aws-transit-north"
    connection_name     = "external-partner-vpn"
    remote_gateway_ip   = "192.0.2.60"
    bgp_enabled         = false  # Static routing
    local_tunnel_cidr   = "169.254.4.0/30"
    remote_tunnel_cidr  = "169.254.4.4/30"
    ha_enabled          = false
    enable_ikev2        = false  # Use IKEv1
    inspected_by_firenet = false
  }
}
```

## Supported IPsec Algorithms

### Phase 1 Authentication
- `SHA-1`
- `SHA-256` (recommended)
- `SHA-384`
- `SHA-512`

### Phase 1 & 2 Encryption
- `3DES`
- `AES-128-CBC`
- `AES-192-CBC`
- `AES-256-CBC` (recommended)
- `AES-128-GCM-64`
- `AES-128-GCM-96`
- `AES-128-GCM-128`
- `AES-256-GCM-64`
- `AES-256-GCM-96`
- `AES-256-GCM-128`
- `NULL-ENCR` (Phase 2 only)

### Phase 2 Authentication
- `NO-AUTH`
- `HMAC-SHA-1`
- `HMAC-SHA-256` (recommended)
- `HMAC-SHA-384`
- `HMAC-SHA-512`

### Diffie-Hellman Groups
- `1` (768-bit MODP)
- `2` (1024-bit MODP)
- `5` (1536-bit MODP)
- `14` (2048-bit MODP) - recommended
- `15` (3072-bit MODP)
- `16` (4096-bit MODP)
- `17` (6144-bit MODP)
- `18` (8192-bit MODP)
- `19` (256-bit ECP)
- `20` (384-bit ECP)
- `21` (521-bit ECP)

## Integration with Network Segmentation

The IPsec connections automatically integrate with the segmentation module when:

1. **Connection naming follows pattern**: `external-<domain-name>-<descriptor>`
2. **BGP is enabled**: Only Transit_BGP connections are segmented
3. **Domain exists**: The domain name must be defined in the segmentation module

Example:
```hcl
# In transit module
external_devices = {
  "prod-onprem" = {
    connection_name = "external-prod-dc1"  # "prod" will match domain
    # ...
  }
}

# In segmentation module
domains = ["prod", "dev", "infra"]
```

## Troubleshooting

### Connection Down
1. Verify remote gateway IP is reachable
2. Check firewall rules allow UDP 500/4500
3. Verify IKE/IPsec parameters match on both sides
4. Check logs in CoPilot > Diagnostics

### BGP Not Establishing
1. Verify BGP ASN configuration
2. Check tunnel IPs are correctly configured
3. Ensure IPsec tunnel is established first
4. Verify BGP is enabled on remote device

### Traffic Not Flowing
1. Check routing tables on both sides
2. Verify security groups/NACLs allow traffic
3. If FireNet is enabled, check firewall policies
4. Verify learned routes are propagated

## Validation Commands

```bash
# Check connection status
terraform state list | grep external_device

# Show connection details
terraform state show 'aviatrix_transit_external_device_conn.external_device["onprem-dc1"]'

# Verify FireNet inspection policy
terraform state show 'aviatrix_transit_firenet_policy.inspection_policies["prod.external-prod-dc1"]'
```

## Important Notes

### Security Considerations
- Pre-shared keys are marked as sensitive
- Algorithm parameters are only used when `custom_algorithms = true`
- FireNet inspection adds additional security layer
- Always use IKEv2 when possible for better security

### Terraform Considerations
- Algorithm parameters are `ForceNew` - changing them recreates the tunnel
- Connection names must be unique within a transit gateway
- Use descriptive connection names for easier management
- Consider using remote state for shared configurations

### Performance Considerations
- BGP convergence time depends on network conditions
- HA tunnels provide redundancy but not load balancing
- FireNet inspection adds latency (~1-2ms)
- Consider enable_max_performance for high-throughput scenarios

## Related Documentation

- [Aviatrix Transit Gateway Documentation](https://docs.aviatrix.com/documentation/latest/building-your-network/transit-gateway.html)
- [Site2Cloud Documentation](https://docs.aviatrix.com/documentation/latest/site-to-site-cloud/site2cloud.html)
- [FireNet Documentation](https://docs.aviatrix.com/documentation/latest/firewall-network/transit-firenet.html)

## Git History

```
07841a1 refactor: conditionally pass algorithm parameters based on custom_algorithms flag
6ae6b3d feat: add custom IPsec algorithm and pre-shared key support for external devices
1b1547b added support for ipsec connections
```

## Summary

The AWS IPsec tunnel implementation provides a flexible, scalable solution for connecting external devices to Aviatrix Transit Gateways. Key highlights:

✅ **Flexible Configuration**: Supports BGP/static routing, HA, custom algorithms
✅ **Security**: Customer-provided PSK, custom algorithms, FireNet integration
✅ **Scalability**: Map-based input allows unlimited external connections
✅ **Integration**: Works with network segmentation and FireNet
✅ **Best Practices**: Sensible defaults, optional advanced features, clear examples
