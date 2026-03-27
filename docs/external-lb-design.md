# Global External Application LB — Design Summary

## Overview

Inbound internet traffic to workloads in Aviatrix spoke VPCs is routed through PAN-OS firewalls for inspection using a **Global External Application Load Balancer** with **Zonal NEGs**. A **Policy Based Forwarding (PBF) rule with enforce-symmetric-return** on PAN-OS handles the asymmetric routing caused by the GFE proxy sourcing all traffic from `35.191.0.0/16`.

## Architecture

```
Client (internet)
    │
    ▼
┌─────────────────────────┐
│  Global Application LB  │  Public anycast IP (EXTERNAL_MANAGED)
│  (Google Front Ends)     │  L7 proxy — terminates HTTP, opens new connection to backend
└──────────┬──────────────┘
           │ Google internal network (35.191.x.x → FW egress NIC)
           ▼
┌─────────────────────────┐
│  PAN-OS Firewall        │  ethernet1/1 (WAN zone)
│  (egress interface)     │
│                         │  PBF: forward to ethernet1/2 via LAN GW
│                         │  DNAT: dst = FW egress IP → workload IP
│                         │  SNAT: src → FW LAN IP (ethernet1/2)
└──────────┬──────────────┘
           │ Via LAN interface → Aviatrix transit → spoke VPC
           ▼
┌─────────────────────────┐
│  Workload VM            │  Responds to FW LAN IP
│  (spoke VPC)            │  Return: VM → FW LAN → enforce-symmetric-return → WAN
└─────────────────────────┘
```

## Why PBF with Enforce-Symmetric-Return

The Global Application LB is a **reverse proxy** — ALL backend traffic (health checks and real user requests) arrives from Google Front End IPs in the `35.191.0.0/16` range. This creates an asymmetric routing problem:

1. **c2s (client-to-server):** GFE `35.191.x.x` → FW ethernet1/1 (WAN) → DNAT → workload via ethernet1/2 (LAN)
2. **s2c (server-to-client):** Workload → FW ethernet1/2 (LAN) → un-NAT → dst becomes `35.191.x.x`
3. **Conflict:** PAN-OS does a route lookup for `35.191.x.x` in the ingress interface's routing table. The `35.191.0.0/16 → LAN GW` route (required for ILB health check responses) resolves to LAN zone, but the session expects WAN zone → `flow_fwd_zonechange` drop.

**Why dual VRs don't solve this:** PAN-OS sessions are NOT bound to a VR. Return (s2c) traffic does an independent route lookup in the *ingress interface's* VR, not the session's originating VR. With dual VRs, the s2c packet arrives on ethernet1/2 (internal-vr), and the `35.191.0.0/16` route in internal-vr still resolves to LAN zone → same zone mismatch.

**Solution:** A PBF rule with `enforce-symmetric-return` on ethernet1/1:
- **c2s:** PBF forwards traffic to ethernet1/2 via LAN GW (aligns with DNAT routing to workload)
- **s2c:** `enforce-symmetric-return` bypasses the routing table entirely, forcing return traffic back out the c2s ingress interface (ethernet1/1) using the recorded next-hop MAC address

This works with a **single virtual router** — no dual VR complexity needed.

## GCP Resource Chain

```
Global Forwarding Rule (per port)
    → Target HTTP Proxy
        → URL Map
            → Backend Service (per transit)
                → Zonal NEG (per firewall, in FW's zone)
                    → FW egress NIC private IP (GCE_VM_IP_PORT)
```

- **Global Address**: Anycast public IP shared across all forwarding rules
- **Zonal NEG**: One per firewall (FWs may be in different zones)
- **Health Check**: Global HTTP health check — probes via Google internal network (35.191.0.0/16)

## PAN-OS Configuration

### Virtual Router (single)
| VR | Interfaces | Routes |
|---|---|---|
| default | ethernet1/1 + ethernet1/2 + loopbacks | default → egress GW (ethernet1/1), RFC1918 → LAN GW (ethernet1/2), Google HC → LAN GW (ethernet1/2) |

### PBF Rule (ELB-SYMRET)
| Field | Value |
|-------|-------|
| From | interface ethernet1/1 |
| Source / Destination / Service | any |
| Action | forward to ethernet1/2 via LAN GW |
| Enforce symmetric return | enabled, nexthop-address-list: egress GW |

The PBF rule serves two purposes:
1. **c2s forwarding:** Overrides routing to send traffic to the LAN side (where DNAT delivers it to the workload)
2. **s2c symmetric return:** Forces return traffic back out ethernet1/1 using the egress gateway's MAC, bypassing the route table and avoiding the zone mismatch

### NAT Rule (per ELB rule)
| Field | Value |
|-------|-------|
| From zone | WAN |
| To zone | WAN |
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
2. **GFE → FW**: GFE terminates HTTP, opens new TCP connection to FW egress NIC private IP via Google internal network (src = 35.191.x.x)
3. **PBF match**: Traffic arrives on ethernet1/1, PBF rule matches → forward to ethernet1/2 via LAN GW, symmetric return enabled
4. **PAN-OS DNAT**: Matches `dst = fw-egress-ip`, rewrites dst to workload IP, SNAT src to LAN IP
5. **FW → Workload**: Packet exits LAN interface, routes through Aviatrix transit to spoke VPC
6. **Workload → FW**: Workload responds to FW LAN IP (SNAT'd address), delivered directly via LAN subnet
7. **PAN-OS un-NAT**: Restores original addresses: src = FW egress IP, dst = 35.191.x.x (GFE)
8. **Symmetric return**: `enforce-symmetric-return` bypasses route lookup, sends packet out ethernet1/1 using egress gateway MAC
9. **GFE → Client**: GFE receives response, proxies back to the original client

## Key Design Decisions

### Why not dual VRs?
PAN-OS sessions are not VR-bound. Return traffic does a route lookup in the *ingress interface's* VR, not the originating VR. Dual VRs add complexity without solving the fundamental asymmetric routing problem. PBF with enforce-symmetric-return solves it directly.

### Why Zonal NEGs (not Internet NEGs)?
| Aspect | Zonal NEGs (chosen) | Internet NEGs |
|--------|---------------------|---------------|
| GFE ↔ Backend path | Google internal network | Public internet |
| Latency | Lower | Higher |
| FW public IP dependency | Not needed for LB | Required (NEG points to public IP) |
| PAN-OS complexity | Single VR + PBF | Single VR, simpler routing |
| ILB HC compatibility | PBF symmetric return isolates flows | Different source IPs avoid conflict |

### Why enforce-symmetric-return works
PAN-OS PBF `enforce-symmetric-return` records the c2s sender's next-hop MAC during session setup. For s2c packets, it bypasses the routing table entirely and forwards through the original c2s ingress interface using the recorded MAC. This avoids the `flow_fwd_zonechange` drop that occurs when the route table resolves to a different egress zone than the session expects.
