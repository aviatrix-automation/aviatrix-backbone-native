# External IPSec Device Connectivity - GCP Transit Module

## Overview

The GCP transit module now supports external IPSec VPN connections to connect on-premises devices, third-party VPN gateways, or other external networks to your Aviatrix transit gateways.

## Features

- **IPSec VPN Connectivity**: Connect external devices via standard IPSec tunnels
- **BGP or Static Routing**: Support for dynamic BGP routing or static routes
- **High Availability**: Primary and backup tunnel support
- **IKEv2 Support**: Configurable IKEv1 or IKEv2
- **FireNet Inspection**: Optional traffic inspection through Palo Alto VM-Series firewalls
- **NCC Integration**: Works alongside Network Connectivity Center (NCC) hub connections

## Configuration Example

### Basic BGP Connection

```hcl
module "gcp_transit" {
  source = "./modules/control/gcp/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "onprem-datacenter-1" = {
      transit_gw_name       = "gcp-transit-useast1"
      connection_name       = "onprem-dc1-vpn"
      remote_gateway_ip     = "203.0.113.10"
      bgp_enabled           = true
      bgp_remote_asn        = "65001"
      local_tunnel_cidr     = "169.254.1.0/30"
      remote_tunnel_cidr    = "169.254.1.4/30"
      ha_enabled            = false
      enable_ikev2          = true
      inspected_by_firenet  = false
    }
  }
}
```

### HA Connection with FireNet Inspection

```hcl
module "gcp_transit" {
  source = "./modules/control/gcp/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "branch-office-london" = {
      transit_gw_name           = "gcp-transit-europe1"
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
module "gcp_transit" {
  source = "./modules/control/gcp/modules/transit"

  # ... other transit configuration ...

  external_devices = {
    "partner-network" = {
      transit_gw_name     = "gcp-transit-uscentral1"
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
| `transit_gw_name` | string | Yes | Name of the transit gateway to attach the connection |
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

Connect your on-premises data center to GCP via IPSec VPN with BGP for dynamic routing:

```hcl
external_devices = {
  "dc-primary" = {
    transit_gw_name           = "gcp-transit-useast1"
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

### 2. Google Cloud Interconnect Alternative

For smaller sites where Cloud Interconnect is cost-prohibitive:

```hcl
external_devices = {
  "remote-office" = {
    transit_gw_name     = "gcp-transit-uswest1"
    connection_name     = "remote-office-vpn"
    remote_gateway_ip   = "198.51.100.50"
    bgp_enabled         = true
    bgp_remote_asn      = "65100"
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

### 3. Third-Party Cloud Provider

Connect to another cloud provider (AWS, Azure, Oracle, Alibaba):

```hcl
external_devices = {
  "alibaba-cloud" = {
    transit_gw_name     = "gcp-transit-asia1"
    connection_name     = "alibaba-cloud-vpn"
    remote_gateway_ip   = "47.52.100.50"
    bgp_enabled         = true
    bgp_remote_asn      = "45102"  # Alibaba ASN
    local_tunnel_cidr   = "169.254.30.0/30"
    remote_tunnel_cidr  = "169.254.30.4/30"
    ha_enabled          = true
    backup_remote_gateway_ip  = "47.52.100.51"
    backup_local_tunnel_cidr  = "169.254.30.8/30"
    backup_remote_tunnel_cidr = "169.254.30.12/30"
    enable_ikev2        = true
    inspected_by_firenet = false
  }
}
```

### 4. Branch Office with Managed Router

Connect branch offices with standard enterprise routers:

```hcl
external_devices = {
  "branch-tokyo" = {
    transit_gw_name     = "gcp-transit-asia1"
    connection_name     = "branch-tokyo"
    remote_gateway_ip   = "192.0.2.10"
    bgp_enabled         = false  # Static routing for simplicity
    local_tunnel_cidr   = "169.254.40.0/30"
    remote_tunnel_cidr  = "169.254.40.4/30"
    ha_enabled          = false  # Single connection for branch
    enable_ikev2        = true
    inspected_by_firenet = true  # Inspect branch traffic
  }
}
```

## GCP-Specific Considerations

### Network Connectivity Center (NCC) Integration

External IPSec devices work **alongside** NCC hub connections:

```
Architecture:
┌──────────────────────────────────────────────┐
│        Aviatrix Transit Gateway              │
│                                              │
│  ┌────────────┐         ┌────────────────┐  │
│  │ BGP over   │         │  IPSec VPN to  │  │
│  │ LAN to     │         │  External      │  │
│  │ NCC Hub    │         │  Device        │  │
│  └────────────┘         └────────────────┘  │
└──────────────────────────────────────────────┘
       │                          │
       ▼                          ▼
   NCC Hub                  On-Premises DC
   (Cloud Router BGP)       (IPSec endpoint)
```

**Key Points:**
- NCC connections use BGP over LAN (no encryption)
- External devices use IPSec VPN (encrypted)
- Both can coexist on the same transit gateway
- Different routing policies can apply to each

### Cloud Router vs External Device

| Feature | Cloud Router (NCC) | External Device (IPSec) |
|---------|-------------------|-------------------------|
| Protocol | BGP over LAN (GRE) | IPSec VPN |
| Encryption | No (within GCP) | Yes (IPSec) |
| Throughput | Higher (no encryption overhead) | Lower (encryption overhead) |
| Use Case | GCP-internal routing | External connectivity |
| Cost | NCC spoke charges | Data transfer charges |

### GCP Firewall Rules

Ensure GCP firewall rules allow IPSec traffic:

```hcl
resource "google_compute_firewall" "allow_ipsec" {
  name    = "allow-ipsec-vpn"
  network = "your-vpc-network"

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]  # IKE and NAT-T
  }

  allow {
    protocol = "esp"  # IPSec ESP
  }

  source_ranges = ["203.0.113.10/32"]  # Remote gateway IP
  target_tags   = ["aviatrix-gateway"]
}
```

## FireNet Inspection

When `inspected_by_firenet = true`, all traffic from the external device connection will be routed through your Palo Alto VM-Series firewalls for inspection. This requires:

1. FireNet enabled on the transit gateway (`fw_amount > 0`)
2. `inspection_enabled = true` on the transit
3. Palo Alto firewalls deployed and attached to the transit

The inspection policy is automatically created by the module.

### Inspection Flow

```
External Device → IPSec Tunnel → Aviatrix Transit → Palo Alto Firewall → Internal Resources
                                       ▲
                                       │
                                  Inspection
                                   Policy
```

## BGP Configuration

### BGP ASN Guidelines

- **Local ASN**: Automatically uses the transit gateway's `aviatrix_gw_asn`
- **Remote ASN**: Must be provided in `bgp_remote_asn` parameter
- **Private ASN Range**: 64512-65534 (for private use)
- **Public ASN**: Any valid public ASN (must be registered)

**Important**: The `aviatrix_gw_asn` is different from `cloud_router_asn`:
- `cloud_router_asn`: Used for BGP with GCP Cloud Router (NCC)
- `aviatrix_gw_asn`: Used for BGP with external devices

### BGP Best Practices

1. **Use different ASNs** for each external connection
2. **Avoid conflicts** with Cloud Router ASN
3. **Document ASN assignments** for troubleshooting
4. **Monitor BGP sessions** via CoPilot
5. **Use BFD** for faster convergence (configured on remote device)

### Example ASN Assignment

```hcl
transits = [
  {
    gw_name          = "gcp-transit-useast1"
    cloud_router_asn = 64512  # For NCC/Cloud Router BGP
    aviatrix_gw_asn  = 64513  # For external device BGP
    # ... other config ...
  }
]

external_devices = {
  "onprem-dc1" = {
    transit_gw_name = "gcp-transit-useast1"
    bgp_remote_asn  = "65001"  # On-premises ASN (different from both above)
    # ... other config ...
  }
}
```

## Tunnel IP Addressing

### Link-Local Addresses (Recommended)

Use RFC 3927 link-local addresses (169.254.0.0/16) for tunnel IPs:

```hcl
local_tunnel_cidr  = "169.254.1.0/30"  # .1 is Aviatrix, .2 is remote
remote_tunnel_cidr = "169.254.1.4/30"  # .5 is Aviatrix HA, .6 is remote HA
```

**Why link-local?**
- Avoids IP conflicts with existing networks
- Standard practice for point-to-point links
- Doesn't consume routable IP space

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
4. View BGP peer status if BGP is enabled

Via Terraform:
```bash
terraform state show 'module.gcp_transit.aviatrix_transit_external_device_conn.external_device["onprem-dc1"]'
```

Via gcloud:
```bash
# Check if IPSec packets are being processed
gcloud compute instances describe gcp-transit-useast1 \
  --zone=us-east1-b \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

### Common Issues

1. **Connection Down**:
   - Verify remote gateway IP is reachable from GCP
   - Check GCP firewall rules allow UDP 500/4500 and ESP
   - Verify IKE/IPSec parameters match on both sides
   - Check GCP VPC firewall rules

2. **BGP Not Establishing**:
   - Verify BGP ASN configuration
   - Check tunnel IPs are correctly configured
   - Ensure IPSec tunnel is established first
   - Verify `aviatrix_gw_asn` is used (not `cloud_router_asn`)

3. **Traffic Not Flowing**:
   - Check routing tables on both sides
   - Verify GCP firewall rules allow application traffic
   - If FireNet is enabled, check Palo Alto firewall policies
   - Check NCC route propagation isn't conflicting

4. **Conflicts with NCC**:
   - Ensure different ASNs for Cloud Router and external devices
   - Check route priorities and preferences
   - Verify no overlapping CIDRs advertised from both sources

### Debug Commands

```bash
# From Aviatrix Controller CLI
show ip bgp summary
show ip bgp neighbors
show ip route

# Check Site2Cloud tunnel status
show site2cloud connection <connection-name>

# Verify IPSec SA
show site2cloud tunnel <connection-name>
```

## Performance Considerations

### Throughput Expectations

IPSec VPN throughput depends on:
- Aviatrix gateway instance size
- Encryption overhead (~20-30%)
- Internet path quality
- Remote device capabilities

| Transit Instance | Expected VPN Throughput |
|------------------|-------------------------|
| n1-standard-8 | Up to 2 Gbps |
| n2-highcpu-8 | Up to 3 Gbps |
| c2-standard-8 | Up to 4 Gbps |

**Note**: For higher throughput, consider GCP Cloud Interconnect or Partner Interconnect.

### Optimization Tips

1. **Use IKEv2** for better performance and reliability
2. **Enable jumbo frames** if supported by remote device
3. **Use TCP MSS adjustment** to avoid fragmentation
4. **Monitor latency** and packet loss via CoPilot
5. **Consider multiple tunnels** with BGP ECMP for higher throughput

## Comparison with Other GCP Connectivity Options

| Feature | External Device (IPSec) | Cloud VPN (GCP Native) | Cloud Interconnect |
|---------|-------------------------|------------------------|-------------------|
| Setup Complexity | Medium | Low | High |
| Throughput | 1-4 Gbps per tunnel | 3-9 Gbps per tunnel | 10-100 Gbps |
| Encryption | IPSec | IPSec | Optional (MACsec) |
| Pricing | Data transfer only | VPN gateway + data | High upfront + monthly |
| SLA | No SLA | 99.9% | 99.9-99.99% |
| Use Case | General VPN | GCP-native VPN | High bandwidth/low latency |
| FireNet Support | ✅ Yes | ❌ No | ❌ No |

## Multi-Cloud Integration

External devices work seamlessly with Aviatrix transit peering:

```
On-Premises DC
      │
      │ (IPSec VPN)
      ▼
GCP Transit Gateway
      │
      │ (Aviatrix Transit Peering with HPE)
      ▼
AWS Transit Gateway ←→ Azure Transit Gateway
```

This allows:
- Single VPN connection from on-premises
- Automatic routing to AWS, Azure, and other clouds
- Centralized FireNet inspection
- Unified network policies

## Related Documentation

- [Aviatrix Transit Gateway Documentation](https://docs.aviatrix.com/documentation/latest/building-your-network/transit-gateway.html)
- [Site2Cloud Documentation](https://docs.aviatrix.com/documentation/latest/site-to-site-cloud/site2cloud.html)
- [GCP NCC Integration](https://docs.aviatrix.com/documentation/latest/native-connectivity/gcp-ncc.html)
- [GCP Cloud VPN Documentation](https://cloud.google.com/network-connectivity/docs/vpn)

## Comparison with AWS and Azure Implementations

This GCP implementation provides feature parity with AWS and Azure modules:

| Feature | AWS | Azure | GCP |
|---------|-----|-------|-----|
| IPSec VPN | ✅ | ✅ | ✅ |
| BGP Support | ✅ | ✅ | ✅ |
| Static Routing | ✅ | ✅ | ✅ |
| HA Support | ✅ | ✅ | ✅ |
| IKEv2 | ✅ | ✅ | ✅ |
| FireNet Inspection | ✅ | ✅ | ✅ |
| Native Integration | TGW (GRE) | vWAN (BGP over LAN) | NCC (BGP over LAN) |

All three implementations use the same `aviatrix_transit_external_device_conn` resource with consistent parameters, ensuring a uniform experience across clouds.
