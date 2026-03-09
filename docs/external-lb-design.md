# Global External Application LB — Design Summary

## Overview

Inbound internet traffic to workloads in Aviatrix spoke VPCs is routed through PAN-OS firewalls for inspection using a **Global External Application Load Balancer** with **Internet NEGs**.

## Architecture

```
Client (internet)
    │
    ▼
┌─────────────────────────┐
│  Global Application LB  │  Public anycast IP (EXTERNAL_MANAGED)
│  (Google Front Ends)     │  L7 proxy — terminates HTTP, opens new connection to backend
└──────────┬──────────────┘
           │ Internet path (not Google internal network)
           ▼
┌─────────────────────────┐
│  PAN-OS Firewall        │  GCP 1:1 NAT: public IP → egress NIC private IP (ethernet1/1)
│  (egress interface)     │
│                         │  DNAT: dst = FW egress IP → workload IP
│                         │  SNAT: src → FW LAN IP (ethernet1/2)
└──────────┬──────────────┘
           │ Via LAN interface → Aviatrix transit → spoke VPC
           ▼
┌─────────────────────────┐
│  Workload VM            │  Responds to FW LAN IP
│  (spoke VPC)            │  Return path: VM → FW LAN → un-NAT → FW WAN → internet → GFE
└─────────────────────────┘
```

## Why Internet NEGs (not Zonal NEGs)

Zonal NEGs (`GCE_VM_IP_PORT`) communicate with backends via Google's **internal network**. Traffic arrives at the FW from GFE IPs in the `35.191.0.0/16` range. After DNAT/SNAT and workload response, the FW un-NATs the return traffic — the destination becomes `35.191.x.x`.

**Conflict:** PAN-OS has static routes for `35.191.0.0/16 → LAN` (required for ILB health check responses). These routes send the un-NAT'd return traffic back into the LAN VPC instead of out the WAN interface to the GFE. ILB health checks require these routes because the FW responds from loopback IPs in the LAN subnet, and GCP source IP validation prevents these responses from going via the WAN interface.

**Solution:** Internet NEGs (`INTERNET_IP_PORT`) route GFE↔backend traffic via the **public internet**. The GFE source IPs are public Google IPs (not `35.191.x.x`), so the return traffic follows the default route (WAN) with no conflict.

## GCP Resource Chain

```
Global Forwarding Rule (per port)
    → Target HTTP Proxy
        → URL Map
            → Backend Service (per transit)
                → Internet NEG (per firewall, 1 endpoint each)
                    → FW public IP (nic0 external IP)
```

- **Global Address**: Anycast public IP shared across all forwarding rules
- **Internet NEG limit**: 1 endpoint per NEG — one NEG per firewall instance
- **Health Check**: Global HTTP health check on the frontend port

## PAN-OS Configuration

### NAT Rule (per ELB rule)
| Field | Value |
|-------|-------|
| From zone | WAN |
| To zone | any |
| Destination | `fw-egress-ip` (FW's own egress NIC private IP) |
| Service | Frontend port (e.g., tcp/80) |
| DNAT | Workload IP + backend port |
| SNAT | dynamic-ip-and-port via ethernet1/2 (LAN) |

### Security Rule (per ELB rule)
| Field | Value |
|-------|-------|
| From zone | WAN |
| To zone | any |
| Destination | `fw-egress-ip` (**pre-NAT** address, not workload IP) |
| Service | Frontend port |
| Action | allow |

**Important:** PAN-OS security rules evaluate the **pre-NAT** destination for DNAT rules, not the post-NAT workload address.

## Terraform Configuration

Defined in `modules/control/gcp/modules/transit/variables.tf` per transit:

```hcl
external_lb_rules = [
  {
    name           = "app-http"
    frontend_port  = 80
    backend_port   = 80
    destination_ip = "10.10.0.10"
    health_check   = true        # Exactly one rule must be true
  },
]
```

## Data Flow (detailed)

1. **Client → LB**: Client sends HTTP to global anycast IP
2. **GFE → FW**: GFE terminates HTTP, opens new TCP connection to FW public IP via internet
3. **GCP NAT**: GCP translates dst from FW public IP to FW egress NIC private IP
4. **PAN-OS DNAT**: Matches `dst = fw-egress-ip`, rewrites dst to workload IP, SNAT src to LAN IP
5. **FW → Workload**: Packet exits LAN interface, routes through Aviatrix transit to spoke VPC
6. **Workload → FW**: Workload responds to FW LAN IP (SNAT'd address), delivered directly via LAN subnet
7. **PAN-OS un-NAT**: Restores original addresses: src = FW egress IP, dst = GFE public IP
8. **FW → GFE**: Routes via default route (WAN), GCP NATs src to FW public IP, reaches GFE via internet
9. **GFE → Client**: GFE proxies the response back to the original client
