# Aviatrix Backbone Native Modules - Supported Use Cases

## Executive Summary

The Aviatrix Backbone Native modules provide a complete Infrastructure-as-Code solution for deploying and managing multi-cloud network infrastructure. The modules support enterprise-grade networking across AWS, Azure, and GCP with advanced features including high-performance encryption, network segmentation, distributed firewalling, and native cloud service integration.

**Version:** 0.3.0+
**Last Updated:** January 2026

---

## Table of Contents

1. [Management & Control Plane](#1-management--control-plane-use-cases)
2. [AWS Transit](#2-aws-transit-use-cases)
3. [Azure Transit](#3-azure-transit-use-cases)
4. [GCP Transit](#4-gcp-transit-use-cases)
5. [Transit Peering](#5-transit-peering-use-cases)
6. [Network Segmentation](#6-network-segmentation-use-cases)
7. [Distributed Cloud Firewall](#7-distributed-cloud-firewall-use-cases)
8. [Common Multi-Cloud Use Cases](#8-common-multi-cloud-use-cases)
9. [Advanced Use Cases](#9-advanced-use-cases)
10. [Deployment Patterns](#10-deployment-patterns)
11. [Feature Support Matrix](#11-feature-support-matrix)

---

## 1. Management & Control Plane Use Cases

### 1.1 Controller Deployment (`modules/mgmt`)

**Use Cases:**
- **Greenfield Deployment**: Deploy new Aviatrix Controller and CoPilot in AWS from scratch
- **Existing VPC Integration**: Deploy into existing AWS VPC infrastructure for brownfield scenarios
- **Automated Initialization**: Automatic controller initialization and AWS account onboarding
- **High Availability Setup**: Controller with appropriate instance sizing for production scale

**Key Features:**
- Controller version management (default: latest, configurable)
- CoPilot co-deployment with configurable storage (default: 100GB data volume)
- AWS SSM Parameter Store integration for secure credential management
- Configurable instance types:
  - Controller: `t3.xlarge` (default), scalable to `t3.2xlarge` for large deployments
  - CoPilot: `m5n.2xlarge` (default), recommended for up to 1000 gateways
- Flexible module configuration:
  - Controller deployment
  - Controller initialization
  - CoPilot deployment
  - CoPilot initialization
  - AWS account onboarding
  - IAM roles creation (optional)

**Typical Scenarios:**
- Initial Aviatrix platform deployment in new AWS environment
- Multi-region controller setup for global enterprises
- Disaster recovery controller deployment in secondary region
- DevOps/IaC-driven controller lifecycle management

**Prerequisites:**
- AWS account with appropriate permissions
- Valid Aviatrix customer ID and license
- DNS/domain name for controller access (recommended)

---

## 2. AWS Transit Use Cases (`modules/control/aws`)

### 2.1 Transit Gateway with TGW Integration

**Use Cases:**
- **High-Performance Transit**: Deploy Aviatrix transit gateways with Insane Mode for 25-100 Gbps throughput per connection
- **AWS TGW Integration**: Connect Aviatrix transit to AWS Transit Gateway with BGP peering for hybrid connectivity
- **Multi-TGW Connectivity**: Support multiple TGW connections per transit gateway (up to 8 BGP connect peers per TGW)
- **Cross-Account TGW Sharing**: Share TGW across multiple AWS accounts via AWS RAM (Resource Access Manager)
- **Regional Hub Architecture**: Central transit hub for VPC-to-VPC and on-premises connectivity

**Key Features:**
- **Performance**: Insane mode enabled by default (c5n.9xlarge or c5n.18xlarge instances)
- **Routing**: BGP ECMP for multi-path load balancing across connect peers
- **Redundancy**: S2C RX balancing for site-to-cloud high availability
- **Security**: Transit FireNet support for centralized traffic inspection
- **Segmentation**: Network segmentation enabled for multi-tenant isolation
- **Advanced Routing**:
  - Preserve AS path disabled by default (can override)
  - Advertise transit CIDR enabled
  - Multi-tier transit enabled for hierarchical architectures
- **Learned CIDRs Approval** (New in v0.3.0):
  - Control route learning from BGP connections
  - Gateway-based approval mode
  - Connection-based approval mode
  - Approved CIDR lists for security

**TGW Connect Architecture:**
- 8 Connect attachments per transit gateway
- 2 Connect peers per attachment (primary + HA)
- GRE tunnel protocol for high performance
- Dynamic BGP route exchange

### 2.2 FireNet Integration

**Use Cases:**
- **East-West Traffic Inspection**: Inspect and control traffic between VPCs and cloud networks
- **Egress Filtering**: Centralized internet egress with deep packet inspection
- **North-South Traffic Control**: Inspect traffic flows between cloud and on-premises
- **Compliance Requirements**: Meet regulatory requirements (PCI-DSS, HIPAA, FedRAMP)
- **Advanced Threat Protection**: IDS/IPS, URL filtering, malware detection

**Key Features:**
- **Firewall Platform**: Palo Alto Networks VM-Series firewall deployment
- **Automatic Configuration**:
  - Security groups (management, LAN, egress) created automatically
  - Source ranges configurable per security zone
- **Key Management**:
  - SSH key pair generation via TLS provider
  - Keys stored in AWS Secrets Manager for secure access
- **High Availability**: Primary + HA firewall pairs for redundancy
- **Bootstrap Integration**:
  - S3 bucket integration for bootstrap files
  - Support for Day 0 configuration
- **Flexible Deployment**:
  - Configurable instance types (default: c5.xlarge)
  - Configurable firewall image and version
  - Per-transit firewall attachment control
- **Inspection Control**:
  - Inspection enabled/disabled per transit
  - Egress enabled/disabled per transit
  - Automatic inspection policy creation

**Supported Firewall Versions:**
- PAN-OS 10.x and 11.x
- Marketplace or custom AMIs

### 2.3 Spoke Gateway Deployment

**Use Cases:**
- **Application VPC Connectivity**: Attach application VPCs to transit for secure communication
- **BGP-Enabled Spokes**: Spoke gateways with BGP for dynamic routing and advanced use cases
- **Custom Route Advertisement**: Fine-grained control over which routes are advertised to transit
- **Insane Mode Spokes**: High-performance spoke connections (up to 25 Gbps)
- **Single IP SNAT**: Centralized NAT for outbound traffic with single source IP
- **Existing VPC Integration**: Attach existing VPCs without re-creating infrastructure

**Key Features:**
- **Deployment Options**:
  - New VPC creation with Aviatrix spoke
  - Existing VPC attachment (use_existing_vpc)
- **Performance**:
  - Configurable instance sizes (default: t3.large)
  - Insane mode support (default: enabled)
  - Max performance mode for multiple tunnels
- **Routing**:
  - BGP support with configurable local AS number
  - Custom VPC routes
  - Included advertised spoke routes for selective advertisement
- **Networking**:
  - EIP allocation control (allocate_new_eip, eip, ha_eip)
  - Single IP SNAT for predictable source IP
  - Attached/unattached state control
- **Transit Attachment**:
  - Specify transit_key to determine which transit to attach to
  - Multiple spokes per transit supported

**BGP Use Cases:**
- Multi-region routing with route aggregation
- Custom AS path prepending
- Conditional route advertisement
- Integration with on-premises BGP routers

### 2.4 External Device Connectivity

**Use Cases:**
- **Site-to-Site VPN**: Connect branch offices and on-premises data centers to AWS
- **IPSec VPN Tunnels**: Standard IPSec connectivity for any compatible device
- **BGP over VPN**: Dynamic routing with external BGP-capable devices
- **HA VPN Connections**: Redundant VPN links with automatic failover
- **Multi-Cloud Connectivity**: Connect non-Aviatrix environments

**Key Features:**
- **VPN Protocols**:
  - IPSec with IKEv1/IKEv2 support
  - GRE tunnels for TGW connectivity
- **Routing**:
  - Static routing for simple configurations
  - BGP routing for dynamic environments
  - Connection-specific or gateway-specific BGP AS numbers
- **High Availability**:
  - Primary + backup tunnel support
  - HA-enabled connections with backup remote gateway
  - Backup BGP AS number configuration
- **Tunnel Configuration**:
  - Custom tunnel CIDRs (local and remote)
  - Jumbo frame support (9000 MTU)
  - Custom algorithms and phase 1 identifiers
- **Route Control**:
  - Manual BGP advertised CIDRs
  - Conditional route advertisement
- **Inspection Integration**:
  - Optional FireNet inspection for external device traffic

---

## 3. Azure Transit Use Cases (`modules/control/azure`)

### 3.1 Virtual WAN Integration

**Use Cases:**
- **Multi-Region Azure Backbone**: Connect multiple Azure regions via Virtual WAN hubs
- **Hub-and-Spoke Architecture**: Aviatrix transit as intelligent spoke to vWAN hub
- **BGP Routing**: Dynamic route exchange with Virtual WAN virtual routers
- **VNET Connectivity**: Connect existing and new VNETs to vWAN hubs
- **Global Transit Network**: Unified connectivity across Azure regions
- **Hybrid Connectivity**: Connect Azure to ExpressRoute and VPN gateways via vWAN

**Key Features:**
- **vWAN Management**:
  - Multiple vWAN configurations (new or existing)
  - Standard vWAN type (optimized for cost and performance)
  - Per-vWAN resource group management
- **Virtual Hubs**:
  - BGP virtual router with dynamic routing
  - Hub-managed VNETs with automatic peering
  - BGP connections to Aviatrix transit gateways
  - Configurable default route propagation to spokes
- **BGP LAN Interfaces**:
  - Up to 3 BGP LAN interfaces per transit gateway
  - One interface per vWAN hub connection
  - Dynamic BGP peering with vHub router
- **Route Control**:
  - Manual spoke CIDR advertisement
  - Customizable route propagation
  - Default route handling per connection
- **Learned CIDRs Approval** (New in v0.3.0):
  - Control route learning from vWAN hubs
  - Gateway or connection-based approval
  - Approved CIDR lists for security

**Topology Support:**
- Any-to-any connectivity via vWAN
- Segmented connectivity with custom route tables
- ExpressRoute and VPN gateway integration

### 3.2 FireNet with Palo Alto

**Use Cases:**
- **Azure Traffic Inspection**: Centralized firewall for intra-Azure and hybrid workloads
- **Compliance Enforcement**: Meet Azure-specific compliance requirements
- **Advanced Threat Protection**: IDS/IPS, URL filtering, malware detection in Azure
- **Egress Control**: Centralized internet egress with inspection

**Key Features:**
- **Firewall Deployment**:
  - Palo Alto VM-Series with Azure-optimized configuration
  - Accelerated networking enabled for performance
  - Primary + HA deployment for redundancy
- **Bootstrap Methods**:
  - **Azure File Share**: Static bootstrap configuration from Azure Storage
  - **Dynamic Panorama**: Centralized management via Palo Alto Panorama
- **Panorama Integration**:
  - Global Panorama configuration (shared across transits)
  - Per-transit Panorama overrides (device group, template, collector group)
  - Dynamic bootstrap for automated onboarding
- **File Share Management**:
  - Bootstrap package path configuration
  - Individual bootstrap file management
  - MD5 checksums for file integrity
  - Configurable quota and access tier
- **Network Configuration**:
  - Automatic NSG (Network Security Group) creation
  - Configurable source ranges (management, LAN, egress)
  - Public IP addresses for management access
- **Authentication**:
  - Password authentication (optional)
  - SSH key support
  - Configurable admin username and password

### 3.3 Spoke Gateway with vWAN Integration

**Use Cases:**
- **Hybrid Spoke Connectivity**: Spokes connected to both Aviatrix transit and vWAN for flexible routing
- **Performance Optimization**: Max performance mode for high-throughput applications
- **BGP LAN Spokes**: Dynamic routing for sophisticated spoke gateway scenarios
- **Application Segmentation**: Separate spoke VNETs for different application tiers

**Key Features:**
- **Dual Connectivity**:
  - Attachment to Aviatrix transit gateway
  - Optional vWAN hub BGP connections
- **Performance Options**:
  - Insane mode for high performance
  - Max performance mode (multiple tunnels)
  - Configurable instance sizes
- **BGP LAN Support**:
  - BGP over LAN interfaces
  - Dynamic route exchange with vWAN
  - Per-spoke BGP configuration
- **VNET Management**:
  - New VNET creation with spoke gateway
  - Existing VNET attachment
  - Custom subnets (private and public)

---

## 4. GCP Transit Use Cases (`modules/control/gcp`)

### 4.1 Network Connectivity Center Integration

**Use Cases:**
- **Multi-Region GCP Backbone**: Connect GCP regions via Network Connectivity Center hubs
- **STAR Topology**: Center-edge group configuration for hub-spoke architectures
- **MESH Topology**: Full mesh connectivity via default group for any-to-any communication
- **Cross-Project Connectivity**: Auto-accept spokes from different GCP projects
- **On-Premises Integration**: Connect on-premises networks via Cloud Router BGP
- **Global Routing**: Unified routing across GCP regions and projects

**Key Features:**
- **NCC Hub Configuration**:
  - Multiple NCC hub support (one per region typically)
  - STAR or MESH topology selection
  - Preset topology configuration
  - Auto-accept for managed projects
- **Cloud Router Integration**:
  - Automated Cloud Router creation
  - BGP peering with Aviatrix transit gateways
  - Configurable Cloud Router ASN (64512-65534)
  - Router appliance spoke configuration
- **BGP LAN Interfaces**:
  - One BGP LAN interface per NCC hub
  - Dedicated VPC per BGP LAN interface
  - Automatic subnet creation (RFC 1918 ranges)
  - Primary + HA BGP sessions
- **Route Exchange**:
  - Dynamic route learning from NCC hubs
  - Manual BGP advertised CIDRs for granular control
  - BGP LAN ActiveMesh enabled
- **High Availability**:
  - HA gateway support with zone placement
  - Redundant BGP sessions per hub
  - Automatic failover
- **Learned CIDRs Approval** (New in v0.3.0):
  - Control route learning from NCC hubs
  - Gateway or connection-based approval
  - Approved CIDR lists for security

**NCC Topology Details:**
- **STAR**: Center group (transit) with edge groups (spokes)
- **MESH**: All spokes in default group with full mesh connectivity

### 4.2 FireNet with Palo Alto

**Use Cases:**
- **GCP Traffic Inspection**: Centralized firewall for intra-GCP and hybrid workloads
- **Compliance Enforcement**: Meet GCP-specific compliance requirements
- **Advanced Threat Protection**: IDS/IPS, URL filtering in GCP environment

**Key Features:**
- **Firewall Deployment**:
  - Palo Alto VM-Series optimized for GCP
  - Primary + HA firewall pairs
  - Zone-aware deployment
- **Bootstrap Configuration**:
  - GCS (Google Cloud Storage) bucket integration
  - Bootstrap package deployment
  - Custom bootstrap files support
- **Network Configuration**:
  - Management, LAN, and egress interfaces
  - Configurable firewall rules via source ranges
  - Public IP addresses for management
- **Sizing Options**:
  - Configurable instance types (default: n2-standard-4)
  - Firewall image and version selection
  - Service account configuration

### 4.3 Spoke Gateway Deployment

**Use Cases:**
- **VPC Connectivity**: Attach application VPCs to Aviatrix transit for secure communication
- **Insane Mode Spokes**: High-performance connections (up to 25 Gbps)
- **Custom Route Control**: Customize advertised and VPC routes
- **Static Routing Only**: No BGP support (platform limitation)
- **NCC Spoke Attachment**: Traditional GCP VPC spokes attached to NCC hubs

**Key Features:**
- **Deployment Options**:
  - New VPC creation with Aviatrix spoke
  - Configurable per spoke (region, instance size, CIDR)
- **Performance**:
  - Insane mode support (default: enabled)
  - Max performance mode for multiple tunnels
  - Configurable instance sizes (default: n1-standard-1)
- **Routing**:
  - Custom VPC routes
  - Included advertised spoke routes
  - **Note: BGP is NOT supported for GCP spoke gateways**
- **Networking**:
  - EIP allocation control (allocate_new_eip, eip, ha_eip)
  - Single IP SNAT for predictable source IP
  - Attached/unattached state control
- **Transit Attachment**:
  - Specify transit_gw_name to determine which transit to attach to
  - Multiple spokes per transit supported

**Important Limitations:**
- ❌ **BGP NOT supported** on GCP spoke gateways (Aviatrix platform limitation)
- ❌ No local AS number configuration
- ❌ No dynamic routing capabilities
- ✅ Static routing only via custom VPC routes

**NCC VPC Spokes:**
- Separate from Aviatrix spoke gateways
- Traditional GCP VPC attachment to NCC hub
- Configured via `spokes` variable (not `aviatrix_spokes`)
- Auto-accept from specified projects

---

## 5. Transit Peering Use Cases (`modules/control/peering`)

### 5.1 Full-Mesh Peering

**Use Cases:**
- **Same-Cloud Peering**: Full mesh connectivity within AWS, Azure, or GCP
- **Cross-Cloud Peering**: Full mesh connectivity between different cloud providers
- **Automated Discovery**: Automatic transit gateway discovery via Aviatrix controller
- **Dynamic Peering**: Automatically create peerings as new transits are added
- **Multi-Region Backbone**: Connect transit gateways across regions

**Key Features:**
- **Automatic Discovery**:
  - Data source queries Aviatrix controller for all transit gateways
  - No manual gateway list maintenance required
  - HA gateway exclusion (gateways ending with `-hagw` automatically excluded)
- **Intelligent Pairing**:
  - Duplicate peering prevention
  - Same-cloud pairs pruned from cross-cloud peering
  - Cloud type detection (AWS=1, GCP=4, Azure=8)
- **Credential Management**:
  - Controller credentials via AWS SSM Parameter Store
  - Secure, centralized credential management
- **Peering Types**:
  - Same-cloud: AWS-AWS, Azure-Azure, GCP-GCP
  - Cross-cloud: AWS-Azure, AWS-GCP, Azure-GCP

**Peering Logic:**
1. Discover all transit gateways from controller
2. Group primary gateways by cloud type
3. Create same-cloud full mesh within each cloud
4. Create cross-cloud full mesh between all clouds
5. Exclude HA gateways and duplicate pairs

### 5.2 High-Performance Encryption (HPE)

**Same-Cloud HPE:**

**Use Cases:**
- **Maximum Throughput**: Achieve highest throughput between transits in same cloud
- **Data-Intensive Workloads**: Big data, analytics, video processing within same cloud
- **Regional Mesh**: High-performance regional backbone within AWS, Azure, or GCP

**Key Features:**
- **enable_max_performance**: Creates multiple HPE tunnels (default: enabled)
- **Supported Clouds**: AWS, GCP, Azure
- **Tunnel Configuration**: Multiple tunnels for increased bandwidth
- **Requirements**: Both transit gateways must be in Insane Mode
- **Private Network Option**: Peering over private network when available
- **Single Tunnel Mode**: Reduced tunnel count for specific scenarios

**Important Notes:**
- Does NOT use `enable_insane_mode_encryption_over_internet` (cross-cloud only)
- Does NOT use `tunnel_count` parameter (cross-cloud only)
- Optimized for same-cloud, intra-region or inter-region connectivity

**Cross-Cloud HPE:**

**Use Cases:**
- **Secure High-Performance Connectivity**: Encrypted high-speed connectivity across clouds
- **Multi-Cloud Workloads**: Applications spanning AWS, Azure, and GCP
- **Disaster Recovery**: Fast replication between cloud providers
- **Data Center Extension**: Extend data center across multiple clouds

**Key Features:**
- **enable_insane_mode_encryption_over_internet**: HPE over public internet
- **Configurable Tunnel Count**: 2-20 tunnels (default: 15)
- **Auto-Detection**: Automatically enables for HPE-capable peerings when set to `null`
- **Supported Combinations**:
  - AWS ↔ GCP
  - AWS ↔ Azure
  - GCP ↔ Azure
- **Requirements**: Both transit gateways must be in Insane Mode

**Important Notes:**
- Does NOT use `enable_max_performance` (same-cloud only parameter)
- Uses public internet connectivity with IPSec encryption
- Multiple tunnels for increased bandwidth and redundancy

**Tunnel Count Recommendations:**
- **2-5 tunnels**: Low to moderate bandwidth requirements
- **10-15 tunnels**: High bandwidth requirements (default: 15)
- **15-20 tunnels**: Maximum performance for data-intensive workloads

### 5.3 Private Network Peering

**Use Cases:**
- **Private Connectivity**: Peering over private networks when available (Insane Mode required)
- **AWS PrivateLink**: Peering over AWS backbone
- **Azure Private Link**: Peering over Azure backbone
- **Reduced Costs**: Avoid internet egress charges for same-region peerings
- **Compliance**: Meet requirements for traffic to stay on private networks

**Key Features:**
- **enable_peering_over_private_network**: Enable private network peering
- **Requirements**: Both transit gateways must be in Insane Mode
- **Single Tunnel Mode**: Optional reduced tunnel count
- **Separate Configuration**: Different settings for same-cloud vs cross-cloud

**Use When:**
- Both transits in same region with private connectivity
- Compliance requires traffic to stay off public internet
- Cost optimization for high-volume same-region traffic

---

## 6. Network Segmentation Use Cases (`modules/control/segmentation`)

### 6.1 Domain Management

**Use Cases:**
- **Multi-Tenant Networks**: Segment networks by tenant/customer for SaaS platforms
- **Environment Isolation**: Separate dev, staging, production environments
- **Compliance Requirements**: Network isolation for regulatory compliance (PCI-DSS, HIPAA)
- **Department Segmentation**: Separate IT, finance, operations, HR networks
- **Application Tiers**: Isolate web, app, and database tiers
- **Security Zones**: DMZ, trusted, restricted, public zones

**Key Features:**
- **Domain Creation**:
  - Create domains from list in configuration
  - Domain-based traffic segmentation
  - Automatic association of gateways to domains
- **Connection Policies**:
  - Define which domains can communicate (allow/deny)
  - Granular control over inter-domain traffic
  - Policy priority and ordering
- **Gateway Associations**:
  - Automatic associations based on naming conventions
  - Transit and spoke gateway support
  - Domain inference from gateway names

**Domain Examples:**
```
domains = ["production", "staging", "development", "dmz", "shared-services"]
```

**Connection Policy Examples:**
```
connection_policy = {
  "prod-to-shared" = {
    domain_1 = "production"
    domain_2 = "shared-services"
  }
  "staging-to-shared" = {
    domain_1 = "staging"
    domain_2 = "shared-services"
  }
}
```

### 6.2 Automatic Associations

**Transit Connections:**

**Use Cases:**
- **External BGP Connections**: Auto-assign Site2Cloud BGP tunnels to domains
- **TGW Connections**: Associate AWS TGW connections with domains
- **On-Premises Networks**: Assign on-premises connections to appropriate domains

**Logic:**
- Connections with names starting with `external-` are analyzed
- Domain is inferred by matching domain names within connection name
- Only BGP-enabled Site2Cloud tunnels are associated
- **Supported**: AWS (cloud_type=1) and GCP (cloud_type=4) transit connections

**Example:**
- Connection name: `external-production-tgw-abc123`
- Inferred domain: `production`

**Azure Spokes:**

**Use Cases:**
- **Spoke Gateway Segmentation**: Auto-assign Azure spoke gateways to domains
- **VNET Isolation**: Automatic domain membership based on spoke name
- **Multi-Tenant Azure**: Isolate customer VNETs by domain

**Logic:**
- Azure spoke gateways (cloud_type=8) are analyzed
- Domain is inferred by matching domain name segments in gateway name
- HA gateways (ending with `-hagw`) are automatically excluded

**Example:**
- Gateway name: `azure-production-spoke-east`
- Inferred domain: `production`

**Important Notes:**
- Gateway naming conventions must include domain names
- Case-sensitive matching
- First matching domain is selected
- Manual associations possible via Aviatrix controller if needed

### 6.3 Connection Policies

**Use Cases:**
- **Allow/Deny Rules**: Define which domains can communicate
- **Zero-Trust Architecture**: Default deny with explicit allows
- **Dynamic Policy Updates**: Update policies without gateway changes
- **Compliance Enforcement**: Implement network isolation policies
- **Segmentation Testing**: Verify isolation between domains

**Policy Configuration:**
```hcl
connection_policy = {
  "allow-prod-to-db" = {
    domain_1 = "production-app"
    domain_2 = "production-db"
  }
  "allow-dev-to-shared" = {
    domain_1 = "development"
    domain_2 = "shared-services"
  }
}
```

**Best Practices:**
- Start with default deny (no policies)
- Add explicit allows based on application requirements
- Use descriptive policy names
- Document policy justifications
- Regular policy audits

### 6.4 Operational Considerations

**Two-Stage Apply:**

Due to Terraform `for_each` dependencies on dynamic data, use two-stage apply:

```bash
# Stage 1: Apply data sources and API calls
terraform apply \
  -target=data.aviatrix_spoke_gateways.all_spoke_gws \
  -target=data.aviatrix_transit_gateways.all_transit_gws \
  -target=terracurl_request.aviatrix_connections

# Stage 2: Apply full configuration
terraform apply
```

**Data Refresh:**
- Data sources cached in Terraform state after first apply
- Use `terraform refresh` or `terraform taint` to update cached data
- Re-run apply to pick up changes in Aviatrix connections

---

## 7. Distributed Cloud Firewall Use Cases (`modules/control/dcf`)

### 7.1 Smart Groups

**Use Cases:**
- **Dynamic Grouping**: Group resources by tags or CIDR ranges
- **Application Groups**: Group by application tier (web servers, app servers, databases)
- **Security Zones**: Group by security level (DMZ, trusted zone, restricted zone)
- **Geographic Groups**: Group by region or location (US-East, EU-West)
- **Environment Groups**: Group by environment (prod, staging, dev)
- **Compliance Groups**: Group by compliance requirements (PCI, HIPAA)

**Key Features:**
- **CIDR-Based Groups**:
  - Define groups by IP CIDR ranges
  - Support for RFC 1918 and public IPs
  - IPv4 support
- **Tag-Based Groups**:
  - Cloud provider tags (AWS tags, Azure tags, GCP labels)
  - Dynamic membership based on tag values
  - Automatic updates as tags change
- **Reusability**:
  - Smart groups used across multiple policies
  - Single source of truth for grouping logic
  - Easy to update group definitions

**Example Smart Groups:**
```hcl
smarties = {
  "web-servers" = {
    tags = {
      "tier" = "web"
      "env"  = "production"
    }
  }
  "database-servers" = {
    cidr = "10.100.0.0/24"
  }
  "public-internet" = {
    cidr = "0.0.0.0/0"
  }
}
```

### 7.2 Distributed Firewall Policies

**Use Cases:**
- **Micro-Segmentation**: Fine-grained traffic control between workloads
- **Application Security**: Protect specific applications and services
- **Compliance Enforcement**: Enforce security policies automatically
- **Zero-Trust Security**: Implement zero-trust network access (ZTNA)
- **Threat Prevention**: Block malicious traffic patterns
- **Lateral Movement Prevention**: Prevent attacker lateral movement

**Key Features:**
- **Priority-Based Ordering**:
  - Policies evaluated in priority order (lower number = higher priority)
  - First matching rule determines action
  - Explicit priority configuration required
- **Action Types**:
  - **PERMIT**: Allow traffic matching rule
  - **DENY**: Block traffic matching rule
- **Protocol Support**:
  - Any protocol
  - TCP with port ranges
  - UDP with port ranges
  - ICMP
- **Port Ranges**:
  - Single ports: `["80"]`
  - Port ranges: `["8000-8999"]`
  - Multiple ranges: `["80", "443", "8080-8090"]`
- **Logging Options**:
  - Enable/disable logging per rule
  - Watch mode for monitoring without enforcement
- **Smart Group Matching**:
  - Source smart groups (multiple supported)
  - Destination smart groups (multiple supported)
  - Group-to-group policies

**Example Policies:**
```hcl
policies = {
  "allow-web-to-app" = {
    priority         = 100
    action           = "PERMIT"
    protocol         = "TCP"
    port_ranges      = ["8080", "8443"]
    logging          = true
    watch            = false
    src_smart_groups = ["web-servers"]
    dst_smart_groups = ["app-servers"]
  }
  "deny-internet-to-db" = {
    priority         = 50
    action           = "DENY"
    protocol         = "ANY"
    port_ranges      = []
    logging          = true
    watch            = false
    src_smart_groups = ["public-internet"]
    dst_smart_groups = ["database-servers"]
  }
}
```

**Policy Best Practices:**
- Reserve low priorities (1-100) for critical deny rules
- Use mid priorities (100-500) for application allows
- Use high priorities (500+) for broad allows
- Always enable logging for deny rules
- Use watch mode for testing new policies
- Document policy purpose in resource names

### 7.3 Default Action Rule

**Use Cases:**
- **Default Deny**: Block all traffic not explicitly allowed (recommended)
- **Default Permit**: Allow all traffic except explicitly blocked
- **Audit Mode**: Log all traffic for analysis before enforcement

**Key Features:**
- **Actions**:
  - **DENY**: Block traffic not matching any policy (recommended)
  - **PERMIT**: Allow traffic not matching any policy
- **Logging**:
  - Enable/disable logging for default action
  - Critical for visibility into blocked traffic
- **Global Application**:
  - Applies to all traffic not matching specific policies
  - Last rule evaluated (lowest priority)

**Configuration:**
```hcl
distributed_firewalling_default_action_rule_action = "DENY"
distributed_firewalling_default_action_rule_logging = true
```

**Recommendations:**
- Use "DENY" as default action for zero-trust security
- Always enable logging on default action
- Monitor logs before implementing deny policies
- Start with "PERMIT" + logging for migration scenarios

### 7.4 DCF Activation

**Key Features:**
- **Global Enable/Disable**:
  - `enable_distributed_firewalling` variable
  - Activate DCF for entire controller
  - Can be enabled/disabled without destroying policies
- **Phased Rollout**:
  - Deploy policies in watch mode first
  - Analyze logs before enforcement
  - Gradually move from watch to enforce

---

## 8. Common Multi-Cloud Use Cases

### 8.1 Hybrid Cloud Connectivity

**Scenario**: Connect on-premises data center to multi-cloud environment with consistent networking and security

**Components Used:**
- AWS Transit (TGW integration + External devices for IPSec/BGP)
- Azure Transit (vWAN integration for ExpressRoute)
- GCP Transit (NCC integration for Cloud Interconnect)
- Transit Peering (cross-cloud connectivity)
- Segmentation (isolate on-prem from cloud environments)

**Architecture:**
```
On-Premises DC
     │
     ├─── IPSec/BGP ──→ AWS Transit (TGW)
     │                       │
     ├─── ExpressRoute ──→ Azure Transit (vWAN)
     │                       │
     └─── Cloud Interconnect ──→ GCP Transit (NCC)
                                 │
                         Transit Peering (Full Mesh)
                                 │
                         Application Workloads
```

### 8.2 Disaster Recovery

**Scenario**: Active-passive or active-active DR across clouds with automated failover

**Components Used:**
- Transit gateways in primary and DR regions/clouds
- Transit peering for cross-region/cross-cloud connectivity
- Segmentation for isolated DR environments
- FireNet for consistent security policies

**Architecture Options:**

**Active-Passive:**
- Primary: AWS US-East-1 (production workloads)
- DR: Azure West-US-2 (standby, no traffic)
- Cross-cloud peering for replication
- Segmentation domain: "production" (primary), "dr-standby" (DR)

**Active-Active:**
- Primary: AWS US-East-1 (50% traffic)
- Secondary: GCP US-Central-1 (50% traffic)
- Cross-cloud peering with HPE
- Shared segmentation domain for active workloads

### 8.3 Multi-Cloud Application Deployment

**Scenario**: Application distributed across AWS, Azure, and GCP with unified networking

**Components Used:**
- Transit gateways in each cloud (AWS, Azure, GCP)
- Spoke gateways for application VPCs/VNets
- FireNet for centralized security inspection
- DCF for micro-segmentation between application tiers
- Transit peering for inter-cloud communication

**Example Application:**
```
AWS:
  - Web Tier (ELB, EC2 Auto Scaling)
  - Spoke VPCs attached to AWS Transit

Azure:
  - App Tier (Azure App Service, VMs)
  - Spoke VNETs attached to Azure Transit

GCP:
  - Data Tier (Cloud SQL, BigQuery)
  - Spoke VPCs attached to GCP Transit

All transits peered via Aviatrix Transit Peering
DCF policies: Web → App → Data (allowed)
Segmentation: production domain
```

### 8.4 Compliance and Security

**Scenario**: Meet regulatory requirements (PCI-DSS, HIPAA, SOC 2, FedRAMP) with network isolation and inspection

**Components Used:**
- Network segmentation (domain isolation by compliance scope)
- DCF policies (micro-segmentation and zero-trust)
- FireNet (traffic inspection and IDS/IPS)
- Logging enabled on all components

**Compliance Domains:**
```
- "pci-scope": Cardholder data environment
- "hipaa-phi": Protected health information
- "general": Non-sensitive workloads
- "dmz": Internet-facing services
- "shared-services": Logging, monitoring, AD
```

**Connection Policies:**
- PCI ↔ General: DENY
- HIPAA ↔ General: DENY
- PCI ↔ Shared Services: PERMIT (logging, monitoring only)
- HIPAA ↔ Shared Services: PERMIT (logging, monitoring only)
- DMZ ↔ PCI: DENY
- DMZ ↔ HIPAA: DENY

**DCF Policies:**
- All traffic inspected by FireNet
- Micro-segmentation within compliance domains
- Default deny with explicit allows
- All policies logged for audit trail

### 8.5 Migration and Consolidation

**Scenario**: Migrate from traditional hub-spoke or MPLS to Aviatrix architecture

**Components Used:**
- Parallel deployment of Aviatrix transits alongside legacy
- Gradual migration of workloads spoke-by-spoke
- Segmentation for migration phases
- External device connections to legacy environment

**Migration Phases:**

**Phase 1: Foundation**
- Deploy Aviatrix Controller
- Deploy transit gateways (parallel to existing)
- Test connectivity and performance

**Phase 2: Pilot Migration**
- Migrate 1-2 non-production spokes
- Validate application functionality
- Fine-tune segmentation and policies

**Phase 3: Gradual Migration**
- Migrate production workloads in waves
- Use segmentation domains: "migrated", "legacy"
- Connection policy between domains during migration
- Monitor and validate

**Phase 4: Cutover and Decommission**
- Complete all spoke migrations
- Remove connections to legacy infrastructure
- Decommission legacy hub-spoke
- Optimize Aviatrix configuration

---

## 9. Advanced Use Cases

### 9.1 Learned CIDRs Approval (New Feature - v0.3.0)

**Use Cases:**
- **Route Control**: Control which BGP-learned routes are accepted from connections
- **Security**: Prevent route hijacking or accidental route advertisement
- **Compliance**: Ensure only approved networks are reachable
- **Multi-Tenant**: Control route learning per tenant connection
- **Route Filtering**: Filter routes from external BGP peers

**Modes:**

**Gateway Mode:**
- Approval on per-gateway basis
- All connections on a gateway share approval settings
- Simpler configuration for uniform policies
- Available since R2.18+

**Connection Mode:**
- Approval on per-connection basis
- Granular control for each BGP connection
- More flexible for complex scenarios
- Available since R2.18+

**Supported Clouds:** AWS, Azure, GCP

**Configuration:**
```hcl
transits = {
  "aws-transit-prod" = {
    # ... other config ...

    # Enable learned CIDRs approval
    learned_cidr_approval = "true"

    # Approval mode: "gateway" or "connection"
    learned_cidrs_approval_mode = "gateway"

    # List of approved CIDRs
    approved_learned_cidrs = [
      "10.100.0.0/16",
      "10.200.0.0/16",
      "192.168.0.0/16"
    ]
  }
}
```

**Important Notes:**
- `learned_cidr_approval` is a **string** type ("true" or "false"), not boolean
- Default: "false" (all learned routes accepted)
- When enabled, only CIDRs in approved list are accepted
- Learned CIDRs not in approved list are rejected
- Works with BGP connections (TGW, external devices, etc.)

### 9.2 Multi-TGW Architecture (AWS)

**Use Cases:**
- **Regional Isolation**: Separate TGWs per region for blast radius containment
- **Security Zones**: Different TGWs for different security levels
- **Cross-Account**: TGW sharing across multiple AWS accounts via RAM
- **Performance**: Distribute load across multiple TGWs

**Key Features:**
- Up to 8 BGP connect peers per Aviatrix transit gateway
- Multiple TGW connections per Aviatrix transit (configured per transit)
- RAM sharing for cross-account TGW access
- Independent route tables per TGW

**Example Configuration:**
```
Aviatrix Transit (us-east-1)
    │
    ├─── TGW-Production (connect peers 1-4)
    │    └── Production VPCs
    │
    ├─── TGW-Development (connect peers 5-8)
    │    └── Development VPCs
    │
    └─── TGW-DMZ (connect peers 1-4)
         └── Internet-facing VPCs
```

**Benefits:**
- Isolation between environments
- Independent scaling and routing policies
- Reduced blast radius
- Compliance boundary enforcement

### 9.3 High-Performance Workloads

**Use Cases:**
- **Big Data**: High-throughput data transfer between clouds for analytics
- **Video Processing**: Low-latency, high-bandwidth video workflows
- **Financial Services**: Ultra-low latency trading platforms
- **AI/ML**: Large dataset transfer for training and inference
- **Database Replication**: High-speed database sync across clouds

**Key Features:**
- **Insane Mode**: 25-100 Gbps per connection
  - Requires c5n.9xlarge or c5n.18xlarge instances
  - Direct attachment to cloud network fabric
- **Max Performance Mode**: Multiple tunnels for increased bandwidth
  - Automatic load balancing across tunnels
  - ECMP for traffic distribution
- **HPE Encryption Over Internet**: Cross-cloud high-performance encryption
  - 15 tunnels by default (configurable 2-20)
  - IPSec encryption without performance penalty

**Performance Tiers:**

| Scenario | Instance Type | Throughput | Use Case |
|----------|--------------|------------|----------|
| Standard | t3.xlarge | 1-2 Gbps | Small workloads |
| Performance | c5n.xlarge | 5-10 Gbps | Medium workloads |
| High Performance | c5n.4xlarge | 10-25 Gbps | Large workloads |
| Insane Mode | c5n.9xlarge | 25-50 Gbps | Very large workloads |
| Maximum | c5n.18xlarge | 50-100 Gbps | Extreme workloads |

**Optimization Tips:**
- Enable max performance for same-cloud peering
- Use insane mode for all high-throughput scenarios
- Configure 15+ tunnels for cross-cloud HPE
- Use jumbo frames (MTU 9000) where supported
- Enable BGP ECMP for multi-path load balancing

---

## 10. Deployment Patterns

### Pattern 1: Greenfield Multi-Cloud

**Scenario**: New multi-cloud deployment from scratch

**Steps:**
1. **Deploy Controller** (modules/mgmt)
   - AWS region selection (closest to ops team)
   - Controller + CoPilot deployment
   - License activation and initialization

2. **Deploy Transit Gateways** (modules/control/aws, azure, gcp)
   - One transit per cloud per region
   - Enable insane mode and FireNet
   - Configure learned CIDRs approval

3. **Configure Peering** (modules/control/peering)
   - Automatic full-mesh peering
   - Enable HPE for same-cloud
   - Enable HPE over internet for cross-cloud

4. **Set up Segmentation** (modules/control/segmentation)
   - Define domains (prod, dev, shared-services)
   - Configure connection policies
   - Automatic gateway associations

5. **Apply DCF Policies** (modules/control/dcf)
   - Define smart groups
   - Create firewall policies
   - Set default deny action

**Timeline**: 2-4 weeks for full deployment

### Pattern 2: Brownfield Migration

**Scenario**: Migrate from existing hub-spoke or MPLS network

**Steps:**
1. **Deploy Controller** alongside existing infrastructure
2. **Deploy Aviatrix Transits** in parallel with legacy hubs
3. **Pilot Migration**: Migrate 1-2 non-critical spokes
4. **Gradual Migration**: Move workloads spoke-by-spoke
5. **Implement Segmentation** during migration for phased access
6. **Decommission Legacy** infrastructure after full migration

**Key Considerations:**
- Maintain connectivity to legacy during migration
- Use segmentation domains: "migrated", "legacy"
- Connection policy between domains during migration
- Gradual cutover per application

**Timeline**: 3-6 months for full migration

### Pattern 3: Hub-and-Spoke per Cloud

**Scenario**: Independent hub-spoke within each cloud, connected via transit peering

**Architecture:**
```
AWS:
  Transit Gateway (hub)
  └── Spoke VPCs

Azure:
  Transit Gateway (hub)
  └── Spoke VNETs

GCP:
  Transit Gateway (hub)
  └── Spoke VPCs

Cross-Cloud:
  Transit Peering (AWS ↔ Azure ↔ GCP)
```

**Benefits:**
- Cloud-native service integration (TGW, vWAN, NCC)
- Optimized intra-cloud connectivity
- Simplified cross-cloud routing
- Independent scaling per cloud

**Timeline**: 3-5 weeks per cloud

### Pattern 4: Security-First

**Scenario**: Security and compliance as primary drivers

**Steps:**
1. **Deploy Transit Gateways** with FireNet enabled
2. **Route All Traffic** through firewalls (inspection_enabled=true)
3. **Implement DCF Micro-Segmentation**:
   - Smart groups by application tier
   - Zero-trust policies
   - Default deny
4. **Apply Segmentation Policies**:
   - Isolate compliance scopes
   - Separate environments
5. **Enable Comprehensive Logging**:
   - FireNet logs
   - DCF logs
   - Segmentation logs

**Security Controls:**
- All traffic inspected (North-South, East-West)
- Micro-segmentation with DCF
- Network segmentation domains
- Learned CIDRs approval for route security
- Comprehensive audit logging

**Timeline**: 4-6 weeks with security validation

---

## 11. Feature Support Matrix

### 11.1 Cloud Provider Support

| Feature | AWS | Azure | GCP | Notes |
|---------|-----|-------|-----|-------|
| **Transit Gateway** | ✅ | ✅ | ✅ | All clouds supported |
| **Insane Mode** | ✅ | ✅ | ✅ | 25-100 Gbps performance |
| **FireNet** | ✅ | ✅ | ✅ | Palo Alto VM-Series |
| **Spoke Gateway** | ✅ | ✅ | ✅ | All clouds supported |
| **BGP on Spokes** | ✅ | ✅ | ❌ | **GCP: NOT supported** |
| **Native Service Integration** | TGW | vWAN | NCC | Cloud-specific |
| **Transit Peering** | ✅ | ✅ | ✅ | Full mesh support |
| **HPE Same-Cloud** | ✅ | ✅ | ✅ | Max performance |
| **HPE Cross-Cloud** | ✅ | ✅ | ✅ | Internet encryption |
| **Network Segmentation** | ✅ | ✅ | ✅ | All clouds supported |
| **DCF** | ✅ | ✅ | ✅ | All clouds supported |
| **Learned CIDRs Approval** | ✅ | ✅ | ✅ | Gateway/connection mode |

### 11.2 BGP Support Matrix

| Component | AWS | Azure | GCP | Configuration |
|-----------|-----|-------|-----|---------------|
| **Transit Gateway** | ✅ | ✅ | ✅ | BGP with TGW, vWAN, NCC |
| **Spoke Gateway** | ✅ | ✅ | ❌ | `enable_bgp`, `local_as_number` |
| **External Device** | ✅ | ✅ | ✅ | BGP over IPSec |
| **Transit Peering** | ✅ | ✅ | ✅ | BGP for route exchange |
| **BGP over LAN** | ✅ | ✅ | ✅ | For native integrations |

**Important**: GCP spoke gateways do NOT support BGP. Use static routing only.

### 11.3 Performance Tiers

| Instance Type | Throughput | Clouds | Use Case |
|---------------|------------|--------|----------|
| t3.large | 1-2 Gbps | AWS | Development/testing |
| n1-standard-1 | 1-2 Gbps | GCP | Development/testing |
| Standard_D3_v2 | 1-2 Gbps | Azure | Development/testing |
| c5n.xlarge | 5-10 Gbps | AWS | Production workloads |
| c5n.4xlarge | 10-25 Gbps | AWS | High-performance |
| **c5n.9xlarge** | **25-50 Gbps** | **AWS** | **Insane Mode** |
| **c5n.18xlarge** | **50-100 Gbps** | **AWS** | **Maximum performance** |

### 11.4 Firewall Support

| Firewall Vendor | AWS | Azure | GCP | Deployment |
|-----------------|-----|-------|-----|------------|
| Palo Alto Networks | ✅ | ✅ | ✅ | VM-Series |
| Check Point | ✅ | ✅ | ❌ | Via marketplace |
| Fortinet | ✅ | ✅ | ❌ | Via marketplace |

**Note**: This repository specifically implements Palo Alto Networks deployment.

### 11.5 Module Dependencies

| Module | Depends On | Optional | Purpose |
|--------|------------|----------|---------|
| mgmt | - | No | Controller must be deployed first |
| aws/azure/gcp | mgmt | No | Transits require controller |
| peering | aws/azure/gcp | Yes | Requires transits to peer |
| segmentation | aws/azure/gcp | Yes | Requires transits/spokes |
| dcf | aws/azure/gcp | Yes | Requires gateways |

### 11.6 Learned CIDRs Approval

| Parameter | Type | Default | Clouds | Notes |
|-----------|------|---------|--------|-------|
| learned_cidr_approval | string | "false" | AWS, Azure, GCP | "true" or "false" |
| learned_cidrs_approval_mode | string | null | AWS, Azure, GCP | "gateway" or "connection" |
| approved_learned_cidrs | list(string) | null | AWS, Azure, GCP | List of approved CIDRs |

**Available Since**: Aviatrix Controller R2.18+, Module v0.3.0+

---

## 12. Cloud-Native Resources Created and Integrated

### 12.1 AWS Resources

**Transit Module Creates:**

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| **AWS Transit Gateway** | Native AWS routing hub | Amazon side ASN, CIDR blocks |
| **TGW VPC Attachments** | Connect VPCs to TGW | Subnet IDs, transit gateway ID |
| **TGW Connect Attachments** | GRE tunnels for Aviatrix | 4 per transit (8 connect peers total) |
| **TGW Connect Peers** | BGP sessions over GRE | Inside CIDR blocks, BGP ASN |
| **AWS Route Tables** | Routes to TGW | Destination CIDR → TGW |
| **Security Groups** | Firewall network isolation | Management, LAN, egress |
| **EC2 Key Pairs** | SSH access to firewalls | Auto-generated or provided |
| **Secrets Manager Secrets** | Store SSH keys | Private/public key pairs |
| **RAM Resource Shares** | Cross-account TGW sharing | Account IDs, TGW ARN |
| **RAM Resource Associations** | Attach TGW to share | TGW → Resource share |
| **RAM Principal Associations** | Grant account access | Account ID → Resource share |

**Transit Module Integrates With:**

| AWS Service | Integration Purpose | How |
|-------------|-------------------|-----|
| **VPC** | Network foundation | Aviatrix-created or existing |
| **Subnets** | Gateway placement | Public subnets for gateways |
| **Internet Gateway** | Public connectivity | Attached to VPC |
| **NAT Gateway** | Private subnet egress | Optional for private subnets |
| **Route53** | DNS resolution | Optional for custom domains |
| **CloudWatch** | Monitoring and logging | Aviatrix sends logs |
| **S3** | Firewall bootstrap | Bootstrap packages |
| **SSM Parameter Store** | Credential storage | Controller credentials |

**Resources Managed via Aviatrix Provider:**

| Aviatrix Resource | AWS Mapping | Purpose |
|-------------------|-------------|---------|
| aviatrix_transit_gateway | EC2 Instances (c5n family) | Transit gateway |
| aviatrix_spoke_gateway | EC2 Instances | Spoke gateway |
| aviatrix_firenet | Service configuration | FireNet enablement |
| aviatrix_firewall_instance | Palo Alto EC2 | NGFW instances |
| aviatrix_transit_external_device_conn | Site-to-Cloud VPN | External connectivity |

### 12.2 Azure Resources

**Transit Module Creates:**

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| **Virtual WAN (vWAN)** | Global network backbone | Standard SKU, location |
| **Virtual Hub** | Regional routing hub | Address prefix, location |
| **Hub Virtual Network Connection** | Connect VNETs to hub | VNET ID, hub ID |
| **Hub BGP Connection** | BGP with Aviatrix | Peer ASN, IP address |
| **Virtual Network (VNET)** | Network isolation | Address space, subnets |
| **Subnets** | Resource placement | Private/public subnets |
| **Network Security Groups (NSGs)** | Firewall network security | Management, LAN, egress |
| **Public IP Addresses** | External connectivity | Standard SKU, static |
| **Resource Groups** | Resource organization | Per transit, per VNET |
| **Storage Accounts** | Firewall bootstrap | File shares for bootstrap |
| **File Shares** | Bootstrap files | Palo Alto configuration |

**Transit Module Integrates With:**

| Azure Service | Integration Purpose | How |
|--------------|-------------------|-----|
| **Virtual Network** | Network foundation | Aviatrix-created or existing |
| **Virtual Network Gateway** | VPN/ExpressRoute | Optional for hybrid |
| **ExpressRoute** | Dedicated connectivity | Via vWAN hub |
| **Azure Firewall** | Can coexist | Parallel deployment option |
| **Azure Monitor** | Logging and metrics | Aviatrix sends logs |
| **Azure Key Vault** | Secret management | Optional for credentials |
| **Azure DNS** | Name resolution | Private DNS zones |
| **Load Balancer** | Application LB | Frontend for workloads |

**Resources Managed via Aviatrix Provider:**

| Aviatrix Resource | Azure Mapping | Purpose |
|-------------------|---------------|---------|
| aviatrix_transit_gateway | Virtual Machines (D/E series) | Transit gateway |
| aviatrix_spoke_gateway | Virtual Machines | Spoke gateway |
| aviatrix_firenet | Service configuration | FireNet enablement |
| aviatrix_firewall_instance | Palo Alto VMs | NGFW instances |

**Palo Alto Module Creates:**

| Resource | Purpose | Module |
|----------|---------|--------|
| Virtual Machine | Palo Alto firewall | PaloAltoNetworks/swfw-modules |
| Network Interfaces | Firewall NICs | Management, data plane |
| Managed Disks | VM storage | OS and data disks |

### 12.3 GCP Resources

**Transit Module Creates:**

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| **NCC Hub** | Global routing hub | STAR/MESH topology |
| **NCC Groups** | Hub organization | Center, edge, default groups |
| **NCC Spoke (Router Appliance)** | Aviatrix integration | Transit gateway attachment |
| **NCC Spoke (VPC)** | VPC attachment | Link VPCs to hub |
| **Cloud Router** | BGP routing | Per NCC hub, ASN config |
| **Router Interfaces** | BGP session endpoints | IP addresses per interface |
| **BGP Peers** | BGP sessions | Aviatrix ↔ Cloud Router |
| **VPC Network** | Network isolation | Custom mode, subnets |
| **Subnets** | IP ranges | BGP LAN subnets per hub |
| **Compute Addresses** | Static IPs | BGP LAN IP addresses |
| **Firewall Rules** | Network security | Ingress/egress rules |
| **Compute Instances** | Palo Alto firewalls | N2 series instances |
| **Cloud Storage Buckets** | Firewall bootstrap | Bootstrap files |

**Transit Module Integrates With:**

| GCP Service | Integration Purpose | How |
|-------------|-------------------|-----|
| **VPC Network** | Network foundation | Aviatrix-created or existing |
| **Cloud Interconnect** | Dedicated connectivity | Via Cloud Router BGP |
| **Cloud VPN** | Encrypted connectivity | Via Cloud Router BGP |
| **Cloud NAT** | Outbound internet | Can coexist for egress |
| **Cloud DNS** | Name resolution | Private DNS zones |
| **Cloud Logging** | Centralized logging | Aviatrix sends logs |
| **Cloud Monitoring** | Metrics and alerts | Performance monitoring |
| **Cloud Load Balancing** | Application LB | Frontend for workloads |

**Resources Managed via Aviatrix Provider:**

| Aviatrix Resource | GCP Mapping | Purpose |
|-------------------|-------------|---------|
| aviatrix_transit_gateway | Compute Instances (n1/n2 series) | Transit gateway |
| aviatrix_spoke_gateway | Compute Instances | Spoke gateway |
| aviatrix_firenet | Service configuration | FireNet enablement |
| aviatrix_firewall_instance | Palo Alto Instances | NGFW instances |
| aviatrix_transit_external_device_conn | Cloud Router BGP | External BGP connectivity |

**NCC Topology Details:**

| Topology | Groups | Use Case |
|----------|--------|----------|
| **STAR** | Center (transit), Edge (spokes) | Hub-spoke, centralized routing |
| **MESH** | Default (all spokes) | Any-to-any connectivity |

**Cloud Router Configuration:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| ASN | 64512-65534 | Private ASN range |
| BGP Peers | 2 per transit (primary + HA) | Per NCC hub |
| Advertised Routes | Custom CIDRs | Manual BGP advertisement |
| BGP Session | BGP over LAN | Via dedicated VPC |

### 12.4 Multi-Cloud Shared Resources

**Aviatrix Controller Resources:**

| Resource Type | Created By | Purpose |
|---------------|------------|---------|
| **Aviatrix Gateways** | Transit/Spoke modules | All gateway types |
| **Peering Connections** | Peering module | Transit-to-transit peering |
| **Segmentation Domains** | Segmentation module | Network isolation |
| **Domain Associations** | Segmentation module | Gateway-to-domain mapping |
| **DCF Smart Groups** | DCF module | Resource grouping |
| **DCF Policies** | DCF module | Firewall rules |
| **Site2Cloud Connections** | Transit modules | VPN tunnels |
| **FireNet Configuration** | Transit modules | Firewall integration |

**Integration Points:**

| Component | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| **Native Transit Service** | TGW | vWAN | NCC |
| **BGP Integration** | TGW Connect | vHub BGP | Cloud Router |
| **Tunnel Protocol** | GRE | BGP LAN | BGP LAN |
| **High Availability** | Multi-AZ | Availability Zones | Multi-Zone |
| **Encryption** | IPSec | IPSec | IPSec |

### 12.5 Resource Lifecycle

**Creation Order:**

```
1. VPC/VNET/Network (cloud native)
2. Subnets (cloud native)
3. Aviatrix Transit Gateway (Aviatrix)
4. Native Service (TGW/vWAN/NCC)
5. Integration Resources (Connect, BGP)
6. Spoke Gateways (Aviatrix)
7. Firewall Instances (Palo Alto)
8. FireNet Configuration (Aviatrix)
9. Peering Connections (Aviatrix)
10. Segmentation Domains (Aviatrix)
11. DCF Policies (Aviatrix)
```

**Destruction Order:**

```
1. DCF Policies (Aviatrix)
2. Segmentation Domains (Aviatrix)
3. Peering Connections (Aviatrix)
4. FireNet Configuration (Aviatrix)
5. Firewall Instances (Palo Alto)
6. Spoke Gateways (Aviatrix)
7. Integration Resources (Connect, BGP)
8. Native Service (TGW/vWAN/NCC)
9. Aviatrix Transit Gateway (Aviatrix)
10. Subnets (cloud native)
11. VPC/VNET/Network (cloud native)
```

**Dependency Management:**

- Terraform `depends_on` for explicit dependencies
- Implicit dependencies via resource references
- Lifecycle rules for specific resources (ignore_changes)
- Prevent destroy for critical infrastructure

### 12.6 Cost Considerations

**AWS Costs:**

| Resource | Pricing Model | Estimate |
|----------|---------------|----------|
| Transit Gateway | Per hour + data processed | ~$36/month + $0.02/GB |
| TGW Attachments | Per hour | ~$36/month each |
| Aviatrix Gateway | EC2 instance hours | Varies by instance type |
| Data Transfer | Per GB | $0.02/GB |
| Palo Alto Firewall | EC2 + BYOL/PAYG | Varies by license |

**Azure Costs:**

| Resource | Pricing Model | Estimate |
|----------|---------------|----------|
| Virtual WAN | Per hour | ~$0.25/hour |
| Virtual Hub | Per hour + data | ~$0.25/hour + $0.02/GB |
| Aviatrix Gateway | VM instance hours | Varies by VM size |
| Data Transfer | Per GB | $0.02/GB |
| Palo Alto Firewall | VM + BYOL/PAYG | Varies by license |

**GCP Costs:**

| Resource | Pricing Model | Estimate |
|----------|---------------|----------|
| NCC Hub | Per spoke hour | ~$0.09/hour per spoke |
| Cloud Router | Free (data charges apply) | $0 |
| Aviatrix Gateway | Compute instance hours | Varies by machine type |
| Data Transfer | Per GB | $0.12/GB egress |
| Palo Alto Firewall | Compute + BYOL/PAYG | Varies by license |

**Cost Optimization Tips:**

- Use appropriate instance/VM sizes (don't over-provision)
- Enable max performance only when needed
- Monitor data transfer costs (largest variable)
- Use committed use discounts (GCP) or reserved instances (AWS/Azure)
- Consolidate traffic through fewer transits where possible
- Review firewall licensing (BYOL vs PAYG)

---

## Appendix: Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| Terraform | >= 1.0 | Required |
| Aviatrix Controller | 8.0+ | Minimum supported |
| Aviatrix Provider | 8.1.20+ | Module version |
| AWS Provider | >= 5.0 | For AWS modules |
| Azure Provider | >= 3.0 | For Azure modules |
| Google Provider | >= 4.0 | For GCP modules |

---

## Document Version

- **Version**: 1.1
- **Last Updated**: January 2026
- **Module Version**: 0.3.0+
- **Contributors**: Ricardo Trentin, Claude Sonnet 4.5

---

## Support and Documentation

- **Repository**: https://github.com/aviatrix-automation/aviatrix-backbone-native
- **Aviatrix Documentation**: https://docs.aviatrix.com
- **Terraform Registry**: https://registry.terraform.io/providers/AviatrixSystems/aviatrix

---

*This document covers all supported use cases for the Aviatrix Backbone Native modules as of January 2026.*
