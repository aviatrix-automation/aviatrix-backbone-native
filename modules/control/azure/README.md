# Azure 2.1 - Aviatrix Transit with Virtual WAN Integration

This module deploys Aviatrix transit gateways in Azure with Virtual WAN (vWAN) integration, optional Palo Alto firewall deployment, spoke gateways, and VNET connectivity.

## Overview

The module provides:

- **Transit Gateways**: High-performance Aviatrix transit gateways with BGP LAN
- **Virtual WAN Integration**: Azure vWAN with virtual hubs and BGP peering
- **FireNet Integration**: Optional Palo Alto Networks firewall deployment with Azure File Share bootstrap
- **Spoke Gateways**: Aviatrix spoke gateways with optional vWAN connectivity
- **VNET Management**: Create new VNETs or connect existing ones to vWAN hubs

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
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Aviatrix Transit│  │ Aviatrix Spoke  │  │  VNETs          │
│ - BGP LAN       │  │ - BGP LAN       │  │  - New/Existing │
│ - FireNet       │  │ - vWAN BGP      │  │  - Hub peering  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FireNet (Optional)                           │
│  - Palo Alto VM-Series                                          │
│  - Azure File Share bootstrap                                   │
│  - Primary + HA deployment                                      │
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
| mc-spoke | terraform-aviatrix-modules/mc-spoke/aviatrix | 1.6.9 |

## Resources

| Name | Type |
|------|------|
| azurerm_virtual_wan | resource |
| azurerm_virtual_hub | resource |
| azurerm_resource_group | resource |
| azurerm_virtual_network | resource |
| azurerm_subnet | resource |
| azurerm_storage_account | resource |
| azurerm_storage_share | resource |
| aviatrix_firenet | resource |
| aviatrix_firewall_instance | resource |
| aviatrix_transit_external_device_conn | resource |
| aviatrix_spoke_external_device_conn | resource |

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
    virtual_hub_cidr = "10.2.0.0/24"
    azure_asn        = 65515
  }
}
```

### Transit Configuration

```hcl
transits = {
  "az-transit-vnet" = {
    cidr                   = "10.1.0.0/23"
    instance_size          = "Standard_D16_v5"
    account                = "azure-account"
    local_as_number        = 65001
    fw_amount              = 2
    firewall_image_version = "11.2.5"
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
    account       = "azure-account"
    cidr          = "10.10.0.0/24"
    instance_size = "Standard_D4_v5"
    enable_bgp    = true
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
    cidr            = "10.4.0.0/16"
    private_subnets = ["10.4.1.0/24", "10.4.2.0/24"]
    public_subnets  = ["10.4.3.0/24"]
    vwan_hub_name   = "prod"
    existing        = false
  }
}
```

## Outputs

No outputs currently defined.

## Notes

- Transit and spoke gateways connect to vWAN hubs via BGP
- vWAN hubs automatically create hub-managed VNETs for BGP peering
- Firewall bootstrap uses Azure File Shares in storage accounts
- Both new and existing VNETs can be connected to vWAN hubs
- Spokes attached to transits with FireNet are automatically inspected
- Resource groups are auto-created for vWAN, transit, and VNET resources
