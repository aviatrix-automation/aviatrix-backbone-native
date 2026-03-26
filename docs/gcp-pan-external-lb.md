# GCP PAN-OS External LB — Architecture

## Traffic Flow

```
Client ──► Global Application LB (anycast IP, L7 proxy)
               │
               │  GFE proxies request: src = 35.191.x.x
               ▼
          Zonal NEG (GCE_VM_IP_PORT)
               │
               ▼
          PAN-OS Firewall
          ┌─────────────────────────────────────────────────┐
          │  eth1/1 (WAN) ◄── ingress                      │
          │       │                                         │
          │       ├── PBF: forward to eth1/2 via LAN GW    │
          │       ├── DNAT: dst → workload IP               │
          │       └── SNAT: src → FW LAN IP                 │
          │                                                 │
          │  eth1/2 (LAN) ──► egress to workload            │
          │       │                                         │
          │       └── s2c: enforce-symmetric-return          │
          │              bypasses routing → back out eth1/1  │
          └─────────────────────────────────────────────────┘
               │
               ▼
          Aviatrix Transit ──► Spoke VPC ──► Workload VM
```

## The Problem

The Global Application LB is a reverse proxy — ALL traffic (data + health checks) arrives from `35.191.0.0/16`. PAN-OS also needs `35.191.0.0/16 → LAN GW` routes for Aviatrix ILB health check responses.

On return traffic, PAN-OS looks up `35.191.x.x` in the route table → ILB route resolves to **LAN zone** → but the session expects **WAN zone** → `flow_fwd_zonechange` drop.

## The Solution

**PBF rule with `enforce-symmetric-return`** on ethernet1/1:

- **c2s:** PBF forwards to ethernet1/2 via LAN GW (aligns with DNAT to workload)
- **s2c:** Symmetric return bypasses routing, sends return traffic back out ethernet1/1 using the egress gateway's recorded MAC

No dual VRs needed. Single `default` VR with all interfaces.

## PAN-OS Config

| Component | Configuration |
|-----------|--------------|
| **VR** | Single `default` — default → egress GW (eth1/1), RFC1918 → LAN GW (eth1/2), Google HC → LAN GW |
| **PBF** | `ELB-SYMRET` — from interface eth1/1, forward eth1/2 via LAN GW, enforce-symmetric-return via egress GW |
| **DNAT** | Per forwarding rule — match dst=FW egress IP, translate to workload:port, SNAT via eth1/2 |
| **Security** | `Allow-Inbound-*` WAN→any dst=fw-egress-ip (pre-NAT match), `Allow-Any-Out` LAN→WAN |

## GCP Resources

```
Global Address (anycast IP)
  → Forwarding Rule (per port)
    → Target HTTP Proxy → URL Map
      → Backend Service (per transit)
        → Zonal NEG (per FW, GCE_VM_IP_PORT → FW egress NIC private IP)
        → Health Check (HTTP via 35.191.0.0/16)
```
