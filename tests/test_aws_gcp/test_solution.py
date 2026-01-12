"""AWS-GCP Transit peering E2E tests with AWS VPCs.

Topology:
AWS-VM-1 --- AWS-VPC-1 ---\
                           \
                            AWS-Transit <=== Peering ===> GCP-Transit --- GCP-SPOKE --- GCP-VM
                           /
AWS-VM-2 --- AWS-VPC-2 ---/

Deployment order (3 stages):
1. site/ - All AWS + GCP VPCs + VMs (single terraform apply)
2. backbone/ - AWS Transit + GCP Transit + Spoke Gateways + Transit Peering
3. monitoring/ - Configure Gatus dashboard on site-1 to monitor all sites

Environment variables:
- AVX_TFVARS: Path to terraform var file (required)
- AVX_NODESTROY: Set to any value to skip terraform destroy after tests
- TF_VAR_enable_gatus: Set to "true" to enable Gatus health monitoring
"""

import os
from collections.abc import Generator
from pathlib import Path

import pytest

from tests.conftest import (
    VM,
    GatusHealthMonitor,
    terraform_apply,
    terraform_destroy,
    terraform_init,
    terraform_output,
)

# Paths to terraform directories
TEST_DIR = Path(__file__).parent
SITE_DIR = TEST_DIR / "site"
BACKBONE_DIR = TEST_DIR / "backbone"
MONITORING_DIR = TEST_DIR / "monitoring"


@pytest.fixture(scope="session", autouse=True)
def deploy_infrastructure(var_file: str) -> Generator[None, None, None]:
    """Deploy infrastructure in 3 stages.

    Deployment order:
    1. site - All AWS + GCP VPCs + VMs (single terraform apply)
    2. backbone - AWS Transit + GCP Transit + Spoke Gateways + Transit Peering
    3. monitoring - Configure Gatus dashboard on site-1 (if enable_gatus=true)

    Destroy order (reverse):
    1. monitoring
    2. backbone
    3. site

    Environment variables:
    - TF_SKIP_DEPLOY: Skip terraform deployment (use existing infrastructure)
    - AVX_NODESTROY: Skip terraform destroy after tests
    - TF_VAR_enable_gatus: Enable Gatus health monitoring
    """
    # Skip deployment if TF_SKIP_DEPLOY is set
    if os.environ.get("TF_SKIP_DEPLOY"):
        print("\n=== TF_SKIP_DEPLOY set, using existing infrastructure ===")
        yield
        return

    # Deploy site (AWS + GCP combined)
    print("\n=== Deploying site (AWS + GCP) ===")
    terraform_init(SITE_DIR)
    terraform_apply(SITE_DIR, var_file)

    # Deploy backbone (connects sites via transits and spoke gateways)
    print("\n=== Deploying backbone ===")
    terraform_init(BACKBONE_DIR)
    terraform_apply(BACKBONE_DIR, var_file)

    # Deploy monitoring (configure Gatus dashboard on site-1) if Gatus is enabled
    # Note: terraform variable names are case-sensitive (enable_gatus not ENABLE_GATUS)
    if os.environ.get("TF_VAR_enable_gatus", "").lower() == "true":  # noqa: SIM112
        print("\n=== Deploying monitoring (Gatus dashboard) ===")
        terraform_init(MONITORING_DIR)
        terraform_apply(MONITORING_DIR, var_file)

    print("\n=== Infrastructure deployed successfully ===")

    yield

    # Destroy in reverse order (unless AVX_NODESTROY is set)
    if os.environ.get("AVX_NODESTROY"):
        print("\n=== AVX_NODESTROY set, skipping destroy ===")
        return

    print("\n=== Destroying infrastructure ===")

    # Destroy monitoring first (if it was deployed)
    if os.environ.get("TF_VAR_enable_gatus", "").lower() == "true":  # noqa: SIM112
        print("\n=== Destroying monitoring ===")
        try:
            terraform_destroy(MONITORING_DIR, var_file)
        except Exception as e:
            print(f"Warning: monitoring destroy failed: {e}")

    print("\n=== Destroying backbone ===")
    try:
        terraform_destroy(BACKBONE_DIR, var_file)
    except Exception as e:
        print(f"Warning: backbone destroy failed: {e}")

    print("\n=== Destroying site ===")
    try:
        terraform_destroy(SITE_DIR, var_file)
    except Exception as e:
        print(f"Warning: site destroy failed: {e}")


@pytest.fixture(scope="module")
def site_outputs() -> dict:
    """Load combined site terraform outputs."""
    outputs = terraform_output(SITE_DIR)
    if not outputs:
        pytest.skip(f"Terraform state not found: {SITE_DIR}")
    return outputs


@pytest.fixture(scope="module")
def aws_site_outputs(site_outputs: dict) -> dict:
    """Extract AWS site outputs in the expected format."""
    return {
        "sites": {"value": site_outputs["aws_sites"]["value"]},
        "site_config": {"value": site_outputs["aws_site_config"]["value"]},
        "all_site_vpcs": {"value": site_outputs["aws_all_site_vpcs"]["value"]},
        "ssh_private_key_file": {"value": site_outputs["aws_ssh_private_key_file"]["value"]},
    }


@pytest.fixture(scope="module")
def gcp_site_outputs(site_outputs: dict) -> dict:
    """Extract GCP site outputs in the expected format."""
    return {
        "vm": {"value": site_outputs["gcp_vm"]["value"]},
        "vm_vpc_id": {"value": site_outputs["gcp_vm_vpc_id"]["value"]},
        "vm_vpc_name": {"value": site_outputs["gcp_vm_vpc_name"]["value"]},
        "gcp_vpc_info": {"value": site_outputs["gcp_vpc_info"]["value"]},
        "ssh_private_key_file": {"value": site_outputs["gcp_ssh_private_key_file"]["value"]},
    }


@pytest.fixture(scope="module")
def backbone_outputs() -> dict:
    """Load backbone terraform outputs."""
    outputs = terraform_output(BACKBONE_DIR)
    if not outputs:
        pytest.skip(f"Terraform state not found: {BACKBONE_DIR}")
    return outputs


@pytest.fixture(scope="module")
def monitoring_outputs() -> dict:
    """Load monitoring terraform outputs."""
    outputs = terraform_output(MONITORING_DIR)
    if not outputs:
        pytest.skip("Monitoring stage not deployed (set enable_gatus=true)")
    return outputs


# -----------------------------------------------------------------------------
# Site AWS Tests - VPCs
# -----------------------------------------------------------------------------
def test_aws_sites_created(aws_site_outputs: dict) -> None:
    """Verify AWS site VPCs were created."""
    assert "sites" in aws_site_outputs
    sites = aws_site_outputs["sites"]["value"]
    assert len(sites) >= 2, "Expected at least 2 sites"
    for site_name, site in sites.items():
        assert site["vpc_id"] is not None, f"VPC not created for {site_name}"


def test_aws_site_vms_created(aws_site_outputs: dict) -> None:
    """Verify AWS site VMs were created."""
    sites = aws_site_outputs["sites"]["value"]
    for site_name, site in sites.items():
        vm = site["vm"]
        assert vm["public_vm_public_ip"] is not None, f"Public VM IP missing for {site_name}"
        assert vm["private_vm_private_ip"] is not None, f"Private VM IP missing for {site_name}"


# -----------------------------------------------------------------------------
# Site GCP Tests
# -----------------------------------------------------------------------------
def test_gcp_site_vpc_created(gcp_site_outputs: dict) -> None:
    """Verify GCP site VM VPC was created."""
    assert "vm_vpc_id" in gcp_site_outputs
    assert gcp_site_outputs["vm_vpc_id"]["value"] is not None


def test_gcp_site_vms_created(gcp_site_outputs: dict) -> None:
    """Verify GCP site VMs were created (mc-vm-csp output format)."""
    assert "vm" in gcp_site_outputs
    vm = gcp_site_outputs["vm"]["value"]
    assert vm["public_vm_public_ip"] is not None
    assert vm["private_vm_private_ip"] is not None


# -----------------------------------------------------------------------------
# Backbone Tests - Transit Gateways and Spoke Gateways
# -----------------------------------------------------------------------------
def test_aws_transit_created(backbone_outputs: dict) -> None:
    """Verify AWS Aviatrix transit gateway was created."""
    assert "aws_transit_gateway_name" in backbone_outputs
    assert backbone_outputs["aws_transit_gateway_name"]["value"] is not None


def test_gcp_transit_created(backbone_outputs: dict) -> None:
    """Verify GCP Aviatrix transit gateway was created."""
    assert "gcp_transit_gateway_name" in backbone_outputs
    assert backbone_outputs["gcp_transit_gateway_name"]["value"] is not None


def test_transit_peering_created(backbone_outputs: dict) -> None:
    """Verify transit peering was created."""
    assert "transit_peering" in backbone_outputs
    peering = backbone_outputs["transit_peering"]["value"]
    assert peering["aws_transit"] is not None
    assert peering["gcp_transit"] is not None


def test_aws_spoke_gateways_created(backbone_outputs: dict) -> None:
    """Verify AWS spoke gateways were created for site VPCs."""
    assert "aws_spoke_gateways" in backbone_outputs
    spokes = backbone_outputs["aws_spoke_gateways"]["value"]
    assert len(spokes) >= 2, "Expected at least 2 AWS spoke gateways"


def test_gcp_spoke_gateway_created(backbone_outputs: dict) -> None:
    """Verify GCP Aviatrix spoke gateway was created."""
    assert "gcp_spoke_gateway_name" in backbone_outputs
    assert backbone_outputs["gcp_spoke_gateway_name"]["value"] is not None


# -----------------------------------------------------------------------------
# Cross-Cloud Private-to-Private Ping Tests
# -----------------------------------------------------------------------------
def _create_vms(aws_site_outputs: dict, gcp_site_outputs: dict) -> dict[str, VM]:
    """Create VM objects from terraform outputs."""
    aws_ssh_key = aws_site_outputs["ssh_private_key_file"]["value"]
    gcp_ssh_key = gcp_site_outputs["ssh_private_key_file"]["value"]

    sites = aws_site_outputs["sites"]["value"]
    site_names = sorted(sites.keys())

    vms = {}

    # Create VMs for each AWS site
    for site_name in site_names:
        site = sites[site_name]
        vm = site["vm"]

        bastion = VM(
            name=f"aws-{site_name}-bastion",
            private_ip=vm["public_vm_private_ip"],
            public_ip=vm["public_vm_public_ip"],
            ssh_key_path=aws_ssh_key,
        )

        private = VM(
            name=f"aws-{site_name}-private",
            private_ip=vm["private_vm_private_ip"],
            bastion=bastion,
            ssh_key_path=aws_ssh_key,
        )

        vms[f"aws_{site_name}_bastion"] = bastion
        vms[f"aws_{site_name}_private"] = private

    # GCP VMs (mc-vm-csp output format)
    gcp_vm = gcp_site_outputs["vm"]["value"]
    gcp_bastion = VM(
        name="gcp-bastion",
        private_ip=gcp_vm["public_vm_private_ip"],
        public_ip=gcp_vm["public_vm_public_ip"],
        ssh_key_path=gcp_ssh_key,
    )

    gcp_private = VM(
        name="gcp-private",
        private_ip=gcp_vm["private_vm_private_ip"],
        bastion=gcp_bastion,
        ssh_key_path=gcp_ssh_key,
    )

    vms["gcp_bastion"] = gcp_bastion
    vms["gcp_private"] = gcp_private

    return vms


# Cross-cloud ping retry settings (more generous for route propagation)
CROSS_CLOUD_RETRIES = 8
CROSS_CLOUD_RETRY_DELAY = 15


def test_aws_site1_to_gcp_private_ping(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify AWS site-1 private VM can ping GCP private VM."""
    vms = _create_vms(aws_site_outputs, gcp_site_outputs)

    success, output = vms["aws_site-1_private"].ping(
        vms["gcp_private"].private_ip,
        max_retries=CROSS_CLOUD_RETRIES,
        retry_delay=CROSS_CLOUD_RETRY_DELAY,
    )

    assert success, f"AWS-site-1-Private -> GCP-Private ping failed: {output}"


def test_aws_site2_to_gcp_private_ping(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify AWS site-2 private VM can ping GCP private VM."""
    vms = _create_vms(aws_site_outputs, gcp_site_outputs)

    success, output = vms["aws_site-2_private"].ping(
        vms["gcp_private"].private_ip,
        max_retries=CROSS_CLOUD_RETRIES,
        retry_delay=CROSS_CLOUD_RETRY_DELAY,
    )

    assert success, f"AWS-site-2-Private -> GCP-Private ping failed: {output}"


def test_gcp_to_aws_site1_private_ping(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify GCP private VM can ping AWS site-1 private VM."""
    vms = _create_vms(aws_site_outputs, gcp_site_outputs)

    success, output = vms["gcp_private"].ping(
        vms["aws_site-1_private"].private_ip,
        max_retries=CROSS_CLOUD_RETRIES,
        retry_delay=CROSS_CLOUD_RETRY_DELAY,
    )

    assert success, f"GCP-Private -> AWS-site-1-Private ping failed: {output}"


def test_gcp_to_aws_site2_private_ping(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify GCP private VM can ping AWS site-2 private VM."""
    vms = _create_vms(aws_site_outputs, gcp_site_outputs)

    success, output = vms["gcp_private"].ping(
        vms["aws_site-2_private"].private_ip,
        max_retries=CROSS_CLOUD_RETRIES,
        retry_delay=CROSS_CLOUD_RETRY_DELAY,
    )

    assert success, f"GCP-Private -> AWS-site-2-Private ping failed: {output}"


def test_aws_site1_to_site2_private_ping(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify AWS site-1 private VM can ping AWS site-2 private VM (via transit)."""
    vms = _create_vms(aws_site_outputs, gcp_site_outputs)

    success, output = vms["aws_site-1_private"].ping(
        vms["aws_site-2_private"].private_ip,
        max_retries=CROSS_CLOUD_RETRIES,
        retry_delay=CROSS_CLOUD_RETRY_DELAY,
    )

    assert success, f"AWS-site-1-Private -> AWS-site-2-Private ping failed: {output}"


# -----------------------------------------------------------------------------
# Gatus Health Monitoring Tests
# -----------------------------------------------------------------------------
# Gatus retry settings (more generous for container startup)
GATUS_RETRIES = 10
GATUS_RETRY_DELAY = 15


def _get_gatus_urls(aws_site_outputs: dict, gcp_site_outputs: dict) -> dict[str, str]:
    """Extract Gatus URLs from terraform outputs."""
    gatus_urls = {}

    # AWS site Gatus URLs
    sites = aws_site_outputs["sites"]["value"]
    for site_name, site in sites.items():
        gatus_url = site["vm"].get("gatus_url")
        if gatus_url:
            gatus_urls[f"aws_{site_name}"] = gatus_url

    # GCP Gatus URL
    gcp_vm = gcp_site_outputs["vm"]["value"]
    gcp_gatus_url = gcp_vm.get("gatus_url")
    if gcp_gatus_url:
        gatus_urls["gcp"] = gcp_gatus_url

    return gatus_urls


def test_aws_site1_gatus_health(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify AWS site-1 Gatus health endpoint is accessible."""
    gatus_urls = _get_gatus_urls(aws_site_outputs, gcp_site_outputs)

    if "aws_site-1" not in gatus_urls:
        pytest.skip("Gatus not enabled for AWS site-1 (set enable_gatus=true in tfvars)")

    gatus = GatusHealthMonitor(gatus_urls["aws_site-1"])
    success, message = gatus.check_health(
        max_retries=GATUS_RETRIES,
        retry_delay=GATUS_RETRY_DELAY,
    )

    assert success, f"AWS-site-1 Gatus health check failed: {message}"


def test_aws_site2_gatus_health(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify AWS site-2 Gatus health endpoint is accessible."""
    gatus_urls = _get_gatus_urls(aws_site_outputs, gcp_site_outputs)

    if "aws_site-2" not in gatus_urls:
        pytest.skip("Gatus not enabled for AWS site-2 (set enable_gatus=true in tfvars)")

    gatus = GatusHealthMonitor(gatus_urls["aws_site-2"])
    success, message = gatus.check_health(
        max_retries=GATUS_RETRIES,
        retry_delay=GATUS_RETRY_DELAY,
    )

    assert success, f"AWS-site-2 Gatus health check failed: {message}"


def test_gcp_gatus_health(aws_site_outputs: dict, gcp_site_outputs: dict) -> None:
    """Verify GCP Gatus health endpoint is accessible."""
    gatus_urls = _get_gatus_urls(aws_site_outputs, gcp_site_outputs)

    if "gcp" not in gatus_urls:
        pytest.skip("Gatus not enabled for GCP (set enable_gatus=true in tfvars)")

    gatus = GatusHealthMonitor(gatus_urls["gcp"])
    success, message = gatus.check_health(
        max_retries=GATUS_RETRIES,
        retry_delay=GATUS_RETRY_DELAY,
    )

    assert success, f"GCP Gatus health check failed: {message}"


# -----------------------------------------------------------------------------
# Monitoring Dashboard Tests (Stage 3)
# -----------------------------------------------------------------------------
def test_monitoring_dashboard_deployed(monitoring_outputs: dict) -> None:
    """Verify monitoring dashboard was deployed on site-1."""
    assert "dashboard_url" in monitoring_outputs
    assert monitoring_outputs["dashboard_url"]["value"] is not None


def test_monitoring_dashboard_site(monitoring_outputs: dict) -> None:
    """Verify monitoring dashboard is configured on site-1."""
    assert "dashboard_site" in monitoring_outputs
    assert monitoring_outputs["dashboard_site"]["value"] == "site-1"


def test_monitoring_endpoints_configured(monitoring_outputs: dict) -> None:
    """Verify monitoring endpoints are configured for all sites."""
    assert "monitored_endpoints" in monitoring_outputs
    endpoints = monitoring_outputs["monitored_endpoints"]["value"]

    # Should have endpoints for self, other AWS sites, and GCP (8 total with ICMP)
    # Dashboard: health + icmp = 2
    # Site-2: gatus + icmp + ssh = 3
    # GCP: gatus + icmp + ssh = 3
    assert len(endpoints) >= 8, f"Expected at least 8 endpoints, got {len(endpoints)}"

    # Check for expected endpoint names (format: aws-{site}-{region} or gcp-{vpc}-{region})
    endpoint_names = list(endpoints)
    assert any("aws-site-1" in e for e in endpoint_names), "Missing aws-site-1 endpoint"
    assert any("aws-site-2" in e for e in endpoint_names), "Missing aws-site-2 endpoints"
    assert any("gcp-" in e for e in endpoint_names), "Missing GCP endpoints"

    # Verify ICMP endpoints exist
    assert any("icmp" in e for e in endpoint_names), "Missing ICMP endpoints"


def test_monitoring_dashboard_health(monitoring_outputs: dict) -> None:
    """Verify monitoring dashboard is healthy and monitoring all sites."""
    dashboard_url = monitoring_outputs["dashboard_url"]["value"]

    gatus = GatusHealthMonitor(dashboard_url)
    success, message = gatus.check_health(
        max_retries=GATUS_RETRIES,
        retry_delay=GATUS_RETRY_DELAY,
    )

    assert success, f"Monitoring dashboard health check failed: {message}"


def test_monitoring_dashboard_status(monitoring_outputs: dict) -> None:
    """Verify monitoring dashboard shows status for all monitored endpoints."""
    dashboard_url = monitoring_outputs["dashboard_url"]["value"]

    gatus = GatusHealthMonitor(dashboard_url)
    success, status = gatus.get_status()

    if not success:
        pytest.skip(f"Could not get dashboard status: {status}")

    # Verify we have endpoint statuses
    assert isinstance(status, list), "Expected list of endpoint statuses"
    assert len(status) > 0, "Expected at least one monitored endpoint"

    # Print status for debugging
    print(f"\nMonitoring dashboard status ({len(status)} endpoints):")
    for endpoint_group in status:
        group_name = endpoint_group.get("name", "unknown")
        results = endpoint_group.get("results", [])
        print(f"  Group: {group_name}")
        for result in results:
            name = result.get("name", "unknown")
            healthy = result.get("success", False)
            status_icon = "✓" if healthy else "✗"
            print(f"    {status_icon} {name}")
