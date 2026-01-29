# External IPSec Device Connectivity - Azure Transit Module

## Overview

The Azure transit module now supports external IPSec VPN connections to connect on-premises devices, third-party VPN gateways, or other external networks to your Aviatrix transit gateways.

## Features

- **IPSec VPN Connectivity**: Connect external devices via standard IPSec tunnels
- **BGP or Static Routing**: Support for dynamic BGP routing or static routes
- **High Availability**: Primary and backup tunnel support
- **IKEv2 Support**: Configurable IKEv1 or IKEv2
- **FireNet Inspection**: Optional traffic inspection through Palo Alto VM-Series firewalls

## Configuration Example

### Basic BGP Connection

```hcl
module "azure_transit" {
  source = "./modules/control/azure/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "onprem-datacenter-1" = {
      transit_key         = "azure-transit-east"
      connection_name     = "onprem-dc1-vpn"
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

### HA Connection with FireNet Inspection

```hcl
module "azure_transit" {
  source = "./modules/control/azure/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "branch-office-london" = {
      transit_key               = "azure-transit-west"
      connection_name           = "branch-london-vpn"
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
}
```

### Static Routing Connection

```hcl
module "azure_transit" {
  source = "./modules/control/azure/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "partner-network" = {
      transit_key         = "azure-transit-north"
      connection_name     = "partner-vpn"
      remote_gateway_ip   = "192.0.2.50"
      bgp_enabled         = false  # Static routing
      local_tunnel_cidr   = "169.254.3.0/30"
      remote_tunnel_cidr  = "169.254.3.4/30"
      ha_enabled          = false
      enable_ikev2        = false  # Use IKEv1
      inspected_by_firenet = false
    }
  }
}
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `transit_key` | string | Yes | Key of the transit gateway to attach the connection |
| `connection_name` | string | Yes | Name of the IPSec connection |
| `remote_gateway_ip` | string | Yes | Public IP of the remote VPN gateway |
| `bgp_enabled` | bool | Yes | Enable BGP routing (true) or use static routing (false) |
| `bgp_remote_asn` | string | Conditional | Required if `bgp_enabled = true` |
| `local_tunnel_cidr` | string | Optional | Local tunnel IP CIDR (e.g., "169.254.1.0/30") |
| `remote_tunnel_cidr` | string | Optional | Remote tunnel IP CIDR (e.g., "169.254.1.4/30") |
| `ha_enabled` | bool | Yes | Enable high availability with backup tunnel |
| `backup_remote_gateway_ip` | string | Conditional | Required if `ha_enabled = true` |
| `backup_local_tunnel_cidr` | string | Conditional | Required if `ha_enabled = true` |
| `backup_remote_tunnel_cidr` | string | Conditional | Required if `ha_enabled = true` |
| `enable_ikev2` | bool | Optional | Use IKEv2 (true) or IKEv1 (false), default: false |
| `inspected_by_firenet` | bool | Yes | Enable traffic inspection via FireNet |

## Use Cases

### 1. On-Premises Data Center Connectivity

Connect your on-premises data center to Azure via IPSec VPN with BGP for dynamic routing:

```hcl
external_devices = {
  "dc-primary" = {
    transit_key               = "azure-transit-east"
    connection_name           = "onprem-dc-primary"
    remote_gateway_ip         = "203.0.113.100"
    bgp_enabled               = true
    bgp_remote_asn            = "64512"
    local_tunnel_cidr         = "169.254.10.0/30"
    remote_tunnel_cidr        = "169.254.10.4/30"
    ha_enabled                = true
    backup_remote_gateway_ip  = "203.0.113.101"
    backup_local_tunnel_cidr  = "169.254.10.8/30"
    backup_remote_tunnel_cidr = "169.254.10.12/30"
    enable_ikev2              = true
    inspected_by_firenet      = true
  }
}
```

### 2. Third-Party Cloud Provider

Connect to another cloud provider (AWS, GCP, Oracle, etc.) that doesn't have native Aviatrix support:

```hcl
external_devices = {
  "oracle-cloud" = {
    transit_key         = "azure-transit-west"
    connection_name     = "oracle-oci-vpn"
    remote_gateway_ip   = "198.51.100.50"
    bgp_enabled         = true
    bgp_remote_asn      = "31898"  # Oracle OCI ASN
    local_tunnel_cidr   = "169.254.20.0/30"
    remote_tunnel_cidr  = "169.254.20.4/30"
    ha_enabled          = true
    backup_remote_gateway_ip  = "198.51.100.51"
    backup_local_tunnel_cidr  = "169.254.20.8/30"
    backup_remote_tunnel_cidr = "169.254.20.12/30"
    enable_ikev2        = true
    inspected_by_firenet = false
  }
}
```

### 3. Branch Office Connectivity

Connect branch offices with managed VPN devices:

```hcl
external_devices = {
  "branch-ny" = {
    transit_key         = "azure-transit-east"
    connection_name     = "branch-newyork"
    remote_gateway_ip   = "192.0.2.10"
    bgp_enabled         = false  # Static routing for simplicity
    local_tunnel_cidr   = "169.254.30.0/30"
    remote_tunnel_cidr  = "169.254.30.4/30"
    ha_enabled          = false  # Single connection for branch
    enable_ikev2        = true
    inspected_by_firenet = true  # Inspect branch traffic
  }
}
```

## FireNet Inspection

When `inspected_by_firenet = true`, all traffic from the external device connection will be routed through your Palo Alto VM-Series firewalls for inspection. This requires:

1. FireNet enabled on the transit gateway (`fw_amount > 0`)
2. `inspection_enabled = true` on the transit gateway
3. Palo Alto firewalls deployed and attached to the transit

The inspection policy is automatically created by the module.

## BGP Configuration

### BGP ASN Guidelines

- **Local ASN**: Automatically uses the transit gateway's `local_as_number`
- **Remote ASN**: Must be provided in `bgp_remote_asn` parameter
- **Private ASN Range**: 64512-65534 (for private use)
- **Public ASN**: Any valid public ASN (must be registered)

### BGP Best Practices

1. **Use different ASNs** for each external connection
2. **Document ASN assignments** for troubleshooting
3. **Monitor BGP sessions** via CoPilot
4. **Use BFD** for faster convergence (configured on remote device)

## Tunnel IP Addressing

### Link-Local Addresses (Recommended)

Use RFC 3927 link-local addresses (169.254.0.0/16) for tunnel IPs:

```hcl
local_tunnel_cidr  = "169.254.1.0/30"  # .1 is Aviatrix, .2 is remote
remote_tunnel_cidr = "169.254.1.4/30"  # .5 is Aviatrix HA, .6 is remote HA
```

### Private RFC1918 Addresses

Alternatively, use private RFC1918 addresses:

```hcl
local_tunnel_cidr  = "10.255.255.0/30"
remote_tunnel_cidr = "10.255.255.4/30"
```

## Troubleshooting

### Check Connection Status

Via CoPilot:
1. Navigate to **Cloud Fabric > Connections > Site2Cloud**
2. Find your connection by name
3. Check status (green = up, red = down)

Via Terraform:
```bash
terraform state show 'module.azure_transit.aviatrix_transit_external_device_conn.external_device["onprem-dc1"]'
```

### Common Issues

1. **Connection Down**:
   - Verify remote gateway IP is reachable
   - Check firewall rules allow UDP 500/4500
   - Verify IKE/IPSec parameters match on both sides

2. **BGP Not Establishing**:
   - Verify BGP ASN configuration
   - Check tunnel IPs are correctly configured
   - Ensure GRE/IPSec tunnel is established first

3. **Traffic Not Flowing**:
   - Check routing tables on both sides
   - Verify security groups/NSGs allow traffic
   - If FireNet is enabled, check firewall policies

## Comparison with AWS Implementation

This Azure implementation mirrors the AWS external device functionality with the following differences:

| Feature | AWS | Azure |
|---------|-----|-------|
| IPSec VPN | ✅ | ✅ |
| BGP Support | ✅ | ✅ |
| Static Routing | ✅ | ✅ |
| HA Support | ✅ | ✅ |
| IKEv2 | ✅ | ✅ |
| FireNet Inspection | ✅ | ✅ |
| TGW Connect (GRE) | ✅ | ❌ (Azure uses vWAN) |

## Related Documentation

- [Aviatrix Transit Gateway Documentation](https://docs.aviatrix.com/documentation/latest/building-your-network/transit-gateway.html)
- [Site2Cloud Documentation](https://docs.aviatrix.com/documentation/latest/site-to-site-cloud/site2cloud.html)
- [Azure vWAN Integration](https://docs.aviatrix.com/documentation/latest/native-connectivity/azure-vwan.html)
