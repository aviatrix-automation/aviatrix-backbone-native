# Site GCP: GCP VPC + VMs
#
# This creates the GCP site infrastructure:
# - Native GCP VPC with subnet (for test VMs)
# - Spoke gateway is created in backbone/ after transits exist

# -----------------------------------------------------------------------------
# SSH Key (shared)
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "${path.module}/ssh_key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

# -----------------------------------------------------------------------------
# Native GCP VPC for VMs
# Spoke gateway will be created in backbone/ and peered to this VPC
# -----------------------------------------------------------------------------
resource "google_compute_network" "vm_vpc" {
  name                    = "${var.name_prefix}-gcp-vm-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vm_subnet" {
  name          = "${var.name_prefix}-gcp-vm-subnet"
  ip_cidr_range = var.gcp_vm_cidr
  region        = var.gcp_region
  network       = google_compute_network.vm_vpc.id
}

# -----------------------------------------------------------------------------
# Firewall rules for internal traffic
# Note: SSH and ICMP rules are created by the mc-vm module
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-gcp-allow-internal"
  network = google_compute_network.vm_vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = [var.gcp_vm_cidr]
}

# -----------------------------------------------------------------------------
# Test VMs deployed into native VPC
# Routing to other clouds will be set up by backbone after spoke creation
# -----------------------------------------------------------------------------
module "vm" {
  source = "../../../vendor/mc-vm-csp/gcp"

  resource_name_label  = "${var.name_prefix}-gcp"
  zone                 = "${var.gcp_region}-a"
  vpc_id               = google_compute_network.vm_vpc.name
  public_subnet_name   = google_compute_subnetwork.vm_subnet.name
  private_subnet_name  = google_compute_subnetwork.vm_subnet.name
  use_existing_keypair = true
  public_key           = tls_private_key.ssh_key.public_key_openssh
  deploy_private_vm    = true
  machine_type         = "e2-small"

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password

  labels = {
    environment = "e2e-test"
  }
}
