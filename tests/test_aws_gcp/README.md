# AWS-GCP Transit Peering E2E Test

## Topology

```
                    AWS Site                                    GCP Site
    ┌───────────────────────────────────┐         ┌──────────────────────────────┐
    │                                   │         │                              │
    │  Site-1 VPC                       │         │  GCP Spoke VPC               │
    │  ┌────────┐         ┌────────┐    │         │  ┌────────┐   ┌───────────┐  │
    │  │AWS-VM-1│─────────│Spoke-1 │────┼────┐    │  │GCP-Spoke│───│  GCP-VM  │  │
    │  └────────┘         └────────┘    │    │    │  └────┬───┘   └───────────┘  │
    │                                   │    │    │       │                      │
    └───────────────────────────────────┘    │    └───────┼──────────────────────┘
                                             │            │
                                       ┌─────▼────┐ ┌─────▼────┐
                                       │   AWS    │ │   GCP    │
                                       │ Transit  │═│ Transit  │
                                       │          │ │          │
                                       └─────▲────┘ └──────────┘
                                             │
    ┌───────────────────────────────────┐    │
    │  Site-2 VPC                       │    │
    │  ┌────────┐         ┌────────┐    │    │
    │  │AWS-VM-2│─────────│Spoke-2 │────┼────┘
    │  └────────┘         └────────┘    │
    │                                   │
    └───────────────────────────────────┘

    Data Path: AWS-VM → Spoke GW → AWS Transit ←══ Peering ══→ GCP Transit → GCP-Spoke → GCP-VM
```

## Architecture

This test uses a modular, DRY architecture:
- **site/**: Parent module that deploys both AWS and GCP sites in a single run
  - **site/aws/**: Creates N AWS VPCs + VMs
  - **site/gcp/**: Creates GCP VPC + VMs
- **backbone/**: Creates AWS and GCP Aviatrix transit gateways with cross-cloud peering + spoke gateways
- **monitoring/**: Configures Gatus dashboard on site-1 to monitor all sites via ICMP, SSH, and HTTP health checks (optional, requires `TF_VAR_enable_gatus=true`)

Deployment order: site -> backbone -> monitoring (if Gatus enabled)

Adding a new AWS site is as simple as adding an entry to the `sites` variable.

## Structure

```
tests/test_aws_gcp/
├── site/                        # Stage 1: Deploy sites (single terraform apply)
│   ├── main.tf                  # Calls aws/ and gcp/ submodules
│   ├── variables.tf             # Combined AWS + GCP variables
│   ├── outputs.tf               # Re-exports submodule outputs
│   ├── versions.tf              # All providers (AWS multi-region + GCP)
│   ├── aws/                     # AWS submodule
│   │   ├── main.tf              # N VPCs via for_each + modules
│   │   ├── variables.tf         # sites = { site-1 = {...}, site-2 = {...} }
│   │   ├── outputs.tf           # Dynamic site outputs
│   │   └── modules/vpc/         # Reusable VPC module
│   │       ├── main.tf          # AWS VPC + mc-vm-csp
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── gcp/                     # GCP submodule
│       ├── main.tf              # GCP VPC + mc-vm-csp
│       ├── variables.tf
│       └── outputs.tf
├── backbone/                    # Stage 2: Deploy backbone
│   ├── main.tf                  # AWS Transit + GCP Transit + Peering + Spoke Gateways
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── monitoring/                  # Stage 3: Configure Gatus dashboard (optional)
│   ├── main.tf                  # Reads site state, SSHs to site-1, updates Gatus config
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── terraform.tfvars.example
├── test_solution.py
└── README.md
```

## Deployment Order

```bash
# 1. Deploy all sites (AWS + GCP VPCs + VMs)
cd site
terraform init
terraform apply -var-file=/path/to/provider_cred.tfvars -var="enable_gatus=true"

# 2. Deploy backbone (transits + peering + spoke gateways)
cd ../backbone
terraform init
terraform apply -var-file=/path/to/provider_cred.tfvars

# 3. (Optional) Configure Gatus dashboard on site-1
cd ../monitoring
terraform init
terraform apply
```

## Adding a New AWS Site

Simply add an entry to the `sites` variable in `terraform.tfvars`:

```hcl
sites = {
  "site-1" = { region = "us-west-2", cidr = "10.11.0.0/16" }
  "site-2" = { region = "us-west-2", cidr = "10.12.0.0/16" }
  # Add more sites in any supported region:
  # "site-3" = { region = "us-east-1", cidr = "10.13.0.0/16" }
  # "site-4" = { region = "eu-west-1", cidr = "10.14.0.0/16" }
}
```

Supported regions (providers are pre-configured):
- `us-west-2` (default)
- `us-east-1`
- `eu-west-1`
- `ap-southeast-1`

## Running Tests

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AVX_TFVARS` | Yes | Path to terraform variables file |
| `TF_VAR_enable_gatus` | No | Set to "true" to enable Gatus health monitoring |
| `TF_SKIP_DEPLOY` | No | Skip terraform deploy (use existing infrastructure) |
| `AVX_NODESTROY` | No | Skip terraform destroy after tests |

### Full Test Run with Gatus Monitoring (Deploy + Test + Destroy)

```bash
AVX_TFVARS=/path/to/provider_cred.tfvars TF_VAR_enable_gatus=true uv run pytest tests/test_aws_gcp/test_solution.py -v
```

### Full Test Run without Gatus (Deploy + Test + Destroy)

```bash
AVX_TFVARS=/path/to/provider_cred.tfvars uv run pytest tests/test_aws_gcp/test_solution.py -v
```

### Test with Existing Infrastructure

```bash
TF_SKIP_DEPLOY=1 AVX_TFVARS=/path/to/provider_cred.tfvars uv run pytest tests/test_aws_gcp/test_solution.py -v
```

### Deploy, Test, Keep Infrastructure

```bash
AVX_TFVARS=/path/to/provider_cred.tfvars TF_VAR_enable_gatus=true AVX_NODESTROY=1 uv run pytest tests/test_aws_gcp/test_solution.py -v
```

## Cleanup

### Destroy All Infrastructure

```bash
# Destroy in reverse order: backbone first, then site
cd backbone
terraform destroy -var-file=/path/to/provider_cred.tfvars

cd ../site
terraform destroy -var-file=/path/to/provider_cred.tfvars
```

## Test Cases

### AWS Site Tests
- `test_aws_sites_created` - Verify all AWS site VPCs exist
- `test_aws_site_vms_created` - Verify all site VMs exist

### GCP Site Tests
- `test_gcp_site_vpc_created` - Verify GCP VM VPC exists
- `test_gcp_site_vms_created` - Verify GCP VMs exist

### Backbone Tests
- `test_aws_transit_created` - Verify AWS Aviatrix transit gateway
- `test_gcp_transit_created` - Verify GCP Aviatrix transit gateway
- `test_transit_peering_created` - Verify transit peering exists
- `test_aws_spoke_gateways_created` - Verify AWS spoke gateways
- `test_gcp_spoke_gateway_created` - Verify GCP Aviatrix spoke gateway exists

### Connectivity Tests
- `test_aws_site1_to_gcp_private_ping` - AWS site-1 -> GCP
- `test_aws_site2_to_gcp_private_ping` - AWS site-2 -> GCP
- `test_gcp_to_aws_site1_private_ping` - GCP -> AWS site-1
- `test_gcp_to_aws_site2_private_ping` - GCP -> AWS site-2
- `test_aws_site1_to_site2_private_ping` - AWS site-1 <-> site-2 (via transit)

### Gatus Health Monitoring Tests (requires `TF_VAR_enable_gatus=true`)
- `test_aws_site1_gatus_health` - AWS site-1 Gatus endpoint accessible
- `test_aws_site2_gatus_health` - AWS site-2 Gatus endpoint accessible
- `test_gcp_gatus_health` - GCP Gatus endpoint accessible

### Monitoring Dashboard Tests (requires `TF_VAR_enable_gatus=true`)
- `test_monitoring_dashboard_deployed` - Dashboard deployed on site-1
- `test_monitoring_dashboard_site` - Dashboard configured on site-1
- `test_monitoring_endpoints_configured` - All endpoints configured
- `test_monitoring_dashboard_health` - Dashboard health check passes
- `test_monitoring_dashboard_status` - Dashboard shows status for all endpoints

## Network CIDRs (Defaults)

| Component | CIDR | Region | Description |
|-----------|------|--------|-------------|
| AWS Transit VPC | 10.10.0.0/16 | us-west-2 | Aviatrix Transit Gateway VPC |
| AWS site-1 VPC | 10.11.0.0/16 | us-west-2 | VPC with VMs |
| AWS site-2 VPC | 10.12.0.0/16 | us-west-2 | VPC with VMs |
| GCP Transit VPC | 10.20.0.0/16 | us-west1 | Aviatrix Transit Gateway VPC |
| GCP Spoke VPC | 10.22.0.0/24 | us-west1 | Spoke gateway + VMs |

## Key Features

- **DRY Multi-Region**: Add sites by editing a single variable
- **Modular Design**: Reusable VPC module with mc-vm-csp for VMs
- **Aviatrix Spoke Gateways**: Each site VPC gets an Aviatrix spoke gateway for transit attachment
- **Transit Peering**: Aviatrix IPsec peering between AWS and GCP transits
- **No HA by Default**: HA gateways disabled to minimize test costs
