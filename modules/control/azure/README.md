# Azure 2.1 - Aviatrix Transit with Virtual WAN Integration

This module deploys Aviatrix transit gateways in Azure with Virtual WAN (vWAN) integration, optional Palo Alto firewall deployment, spoke gateways, and VNET connectivity.

## Overview

The module provides:

- **Transit Gateways**: High-performance Aviatrix transit gateways with BGP LAN
- **Virtual WAN Integration**: Azure vWAN with virtual hubs and BGP peering
- **FireNet Integration**: Optional Palo Alto Networks firewall deployment with Azure File Share bootstrap
- **Spoke Gateways**: Aviatrix spoke gateways with optional vWAN connectivity and performance tuning
- **VNET Management**: Create new VNETs or connect existing ones to vWAN hubs
- **Route Control**: Configurable route advertisement, propagation, and vHub default route handling

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Virtual WAN                          │
│  - Multiple vWAN configurations                                 │
│  - Standard type                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Virtual WAN Hub                             │
│  - Virtual router with BGP                                      │
│  - Hub managed VNET                                             │
│  - BGP connections to Aviatrix                                  │
│  - Configurable default route propagation                       │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Aviatrix Transit│  │ Aviatrix Spoke  │  │  VNETs          │
│ - BGP LAN       │  │ - BGP LAN       │  │  - New/Existing │
│ - FireNet       │  │ - vWAN BGP      │  │  - Hub peering  │
│ - Manual CIDRs  │  │ - Max Perf      │  │  - Route tables │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FireNet (Optional)                           │
│  - Palo Alto VM-Series                                          │
│  - Azure File Share bootstrap                                   │
│  - Primary + HA deployment                                      │
│  - Accelerated networking enabled                               │
└─────────────────────────────────────────────────────────────────┘
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aviatrix | >= 3.0 |
| azurerm | >= 3.0 |
| aws | >= 4.0 |

## Providers

| Name | Description |
|------|-------------|
| aviatrix | Aviatrix provider for gateway and FireNet management |
| azurerm | Azure provider for vWAN, VNETs, and compute resources |
| aws.ssm | AWS provider for SSM parameter retrieval |

## Modules

| Name | Source | Version |
|------|--------|---------|
| mc-transit | terraform-aviatrix-modules/mc-transit/aviatrix | 8.0.0 |
| mc-spoke | terraform-aviatrix-modules/mc-spoke/aviatrix | 8.0.0 |
| vmseries | PaloAltoNetworks/swfw-modules/azurerm//modules/vmseries | 3.4.4 |
| bootstrap | PaloAltoNetworks/swfw-modules/azurerm//modules/bootstrap | 3.4.4 |

## Resources

| Name | Type |
|------|------|
| azurerm_virtual_wan | resource |
| azurerm_virtual_hub | resource |
| azurerm_virtual_hub_connection | resource |
| azurerm_virtual_hub_bgp_connection | resource |
| azurerm_resource_group | resource |
| azurerm_virtual_network | resource |
| azurerm_subnet | resource |
| azurerm_route_table | resource |
| azurerm_storage_account | resource |
| azurerm_storage_share | resource |
| aviatrix_firenet | resource |
| aviatrix_firewall_instance | resource |
| aviatrix_transit_external_device_conn | resource |
| aviatrix_spoke_external_device_conn | resource |
| time_sleep | resource |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| aws_ssm_region | AWS region for SSM parameter retrieval | `string` | yes |
| region | Azure region for deployment | `string` | yes |
| subscription_id | Azure subscription ID | `string` | yes |
| vwan_configs | Map of Virtual WAN configurations | `map(object)` | no |
| vwan_hubs | Map of Virtual WAN hub configurations | `map(object)` | no |
| transits | Map of transit gateway configurations | `map(object)` | no |
| spokes | Map of spoke gateway configurations | `map(object)` | no |
| vnets | Map of VNET configurations | `map(object)` | no |
| tags | Map of tags to apply to all resources | `map(string)` | no |

### Virtual WAN Configuration

```hcl
vwan_configs = {
  "vwan-prod" = {
    location            = "East US"
    resource_group_name = "rg-vwan-prod"
    existing            = false
  }
}
```

### Virtual WAN Hub Configuration

```hcl
vwan_hubs = {
  "prod" = {
    virtual_hub_cidr                       = "10.2.0.0/24"
    virtual_router_auto_scale_min_capacity = 2          # Default: 2
    azure_asn                              = 65515      # Default: 65515
    propagate_default_route                = true       # Default: true - propagates 0.0.0.0/0 to connected VNets
  }
}
```

### Transit Configuration

```hcl
transits = {
  "az-transit-vnet" = {
    cidr                             = "10.1.0.0/23"
    instance_size                    = "Standard_D16_v5"
    account                          = "azure-account"
    local_as_number                  = 65001
    fw_amount                        = 2
    fw_instance_size                 = "Standard_D3_v2"
    firewall_image_version           = "11.2.5"
    inspection_enabled               = true
    egress_enabled                   = true
    bgp_manual_spoke_advertise_cidrs = "10.0.0.0/8,172.16.0.0/12"  # Optional: manually advertised CIDRs
    vwan_connections = [
      {
        vwan_name     = "vwan-prod"
        vwan_hub_name = "prod"
      }
    ]
    file_shares = {
      "bootstrap" = {
        name                   = "bootstrap"
        bootstrap_package_path = "path/to/package"
      }
    }
  }
}
```

### Spoke Configuration

```hcl
spokes = {
  "az-spoke-vnet" = {
    account                          = "azure-account"
    cidr                             = "10.10.0.0/24"
    instance_size                    = "Standard_D4_v5"
    enable_bgp                       = true
    local_as_number                  = 65010
    enable_max_performance           = true              # Default: true
    disable_route_propagation        = false             # Default: false
    included_advertised_spoke_routes = "10.10.0.0/24"    # Optional: CIDRs to advertise to transit
    spoke_bgp_manual_advertise_cidrs = ["10.10.0.0/24"]  # Optional: CIDRs to advertise to BGP peers (vHub)
    vwan_connections = [
      {
        vwan_name     = "vwan-prod"
        vwan_hub_name = "prod"
      }
    ]
  }
}
```

### VNET Configuration

```hcl
vnets = {
  "workload-vnet" = {
    cidr                = "10.4.0.0/16"
    resource_group_name = "rg-workloads"
    private_subnets     = ["10.4.1.0/24", "10.4.2.0/24"]
    public_subnets      = ["10.4.3.0/24"]
    vwan_hub_name       = "prod"
    existing            = false
  }
}
```

## Outputs

No outputs currently defined.

## Route Handling

### Spoke Route Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable_max_performance` | bool | `true` | Enables maximum performance mode on spoke gateway |
| `disable_route_propagation` | bool | `false` | Disables Azure route propagation on spoke subnets |
| `included_advertised_spoke_routes` | string | `null` | Comma-separated CIDRs to advertise to transit |
| `spoke_bgp_manual_advertise_cidrs` | list(string) | `null` | CIDRs to advertise to BGP peers via spoke external connection |

### Transit Route Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bgp_manual_spoke_advertise_cidrs` | string | `null` | CIDRs to manually advertise from transit |

### vHub Route Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `propagate_default_route` | bool | `true` | Propagates 0.0.0.0/0 to connected VNets via internet_security_enabled |
| `virtual_router_auto_scale_min_capacity` | number | `2` | Minimum routing infrastructure units |

## Azure vHub Limits

- **10,000 routes** per virtual hub (aggregate)
- **1,000 routes** per route table
- **20 route tables** per virtual hub

Use route summarization (`bgp_manual_spoke_advertise_cidrs` or `spoke_bgp_manual_advertise_cidrs`) to stay within limits.

## Notes

- Transit and spoke gateways connect to vWAN hubs via BGP LAN
- vWAN hubs automatically create hub-managed VNETs for BGP peering
- Firewall bootstrap uses Azure File Shares with Palo Alto vmseries module
- Both new and existing VNETs can be connected to vWAN hubs
- Spokes attached to transits with FireNet are automatically inspected
- Resource groups are auto-created for vWAN, transit, and VNET resources
- Route tables are created for private/public subnets (excluding vHub-attached VNETs)
- Time delays (600s) are applied between vHub connections and Aviatrix external connections
- PAN firewalls use accelerated networking by default
