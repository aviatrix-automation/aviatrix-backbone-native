# GCP VM Module
# Deploys public and optional private Ubuntu VMs for connectivity testing

locals {
  public_key = var.use_existing_keypair ? var.public_key : tls_private_key.ssh_key[0].public_key_openssh
  # Extract VPC name from vpc_id (handles mc-spoke format "vpc_name~-~project")
  vpc_name = split("~-~", var.vpc_id)[0]

  # Gatus config without authentication
  gatus_config_no_auth = <<-YAML
endpoints:
  - name: Self
    url: "http://localhost:8080/health"
    interval: 30s
    conditions:
      - "[STATUS] == 200"
YAML

  # Gatus config with basic authentication
  gatus_config_with_auth = <<-YAML
security:
  basic:
    username: "${var.gatus_username}"
    password-bcrypt-base64: "${base64encode(bcrypt(var.gatus_password))}"
endpoints:
  - name: Self
    url: "http://localhost:8080/health"
    interval: 30s
    conditions:
      - "[STATUS] == 200"
YAML

  # Select config based on whether password is set
  default_gatus_config = var.gatus_password != "" ? local.gatus_config_with_auth : local.gatus_config_no_auth
  gatus_config_content = var.gatus_config != "" ? var.gatus_config : local.default_gatus_config

  # Gatus installation script (Docker-based)
  gatus_install_script = <<-EOF
#!/bin/bash
set -e
# Install Docker
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
# Write Gatus config
mkdir -p /etc/gatus
cat > /etc/gatus/config.yaml << 'GATUS_CONFIG'
${local.gatus_config_content}
GATUS_CONFIG
# Run Gatus container with config
docker run -d -p 8080:8080 --name gatus --restart unless-stopped \
  -v /etc/gatus/config.yaml:/config/config.yaml \
  ghcr.io/twin/gatus:stable
EOF
}

# Firewall rule for SSH access
resource "google_compute_firewall" "ssh" {
  name    = "${var.resource_name_label}-allow-ssh"
  network = local.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ingress_cidrs
  target_tags   = ["${var.resource_name_label}-vm"]
}

# Firewall rule for ICMP access
resource "google_compute_firewall" "icmp" {
  name    = "${var.resource_name_label}-allow-icmp"
  network = local.vpc_name

  allow {
    protocol = "icmp"
  }

  source_ranges = var.ingress_cidrs
  target_tags   = ["${var.resource_name_label}-vm"]
}

# Firewall rule for Gatus HTTP access
resource "google_compute_firewall" "gatus" {
  count   = var.enable_gatus ? 1 : 0
  name    = "${var.resource_name_label}-allow-gatus"
  network = local.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = var.ingress_cidrs
  target_tags   = ["${var.resource_name_label}-vm"]
}

# Public VM (has external IP)
resource "google_compute_instance" "public" {
  name         = "${var.resource_name_label}-public-vm"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = var.public_subnet_name

    # Assign ephemeral external IP
    access_config {}
  }

  metadata = merge(
    { ssh-keys = "ubuntu:${local.public_key}" },
    var.enable_gatus ? { startup-script = local.gatus_install_script } : {}
  )

  tags = ["${var.resource_name_label}-vm"]

  labels = var.labels
}

# Private VM (no external IP)
resource "google_compute_instance" "private" {
  count        = var.deploy_private_vm ? 1 : 0
  name         = "${var.resource_name_label}-private-vm"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = var.private_subnet_name
    # No access_config = no external IP
  }

  metadata = {
    ssh-keys = "ubuntu:${local.public_key}"
  }

  tags = ["${var.resource_name_label}-vm"]

  labels = var.labels
}
