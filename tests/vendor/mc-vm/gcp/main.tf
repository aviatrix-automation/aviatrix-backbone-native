# Key pair is used for all ubuntu instances
# Public-Private key generation
resource "tls_private_key" "ssh_key" {
  count     = var.use_existing_keypair ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  count           = var.use_existing_keypair ? 0 : 1
  filename        = "${var.resource_name_label}-priv-key.pem"
  content         = tls_private_key.ssh_key[0].private_key_pem
  file_permission = "0600"
}

# Get my public IP for default ingress rules
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  instance_size = length(var.instance_size) > 0 ? var.instance_size : "n1-standard-1"
  public_key    = var.use_existing_keypair ? var.public_key : tls_private_key.ssh_key[0].public_key_openssh

  zone1 = "${var.region}-${var.az1}"
  zone2 = "${var.region}-${var.az2}"

  # Use for calculating list of default allowed CIDRs for ingress_cidrs if none provided
  my_ip                 = "${chomp(data.http.my_ip.response_body)}/32"
  rfc_1918_cidrs        = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  default_ingress_cidrs = concat(local.rfc_1918_cidrs, [local.my_ip])
  ingress_cidrs         = length(var.ingress_cidrs) > 0 ? var.ingress_cidrs : local.default_ingress_cidrs
}

resource "google_compute_firewall" "ingress_firewall" {
  name          = "${var.resource_name_label}-ingress-firewall"
  network       = var.vpc_id
  source_ranges = local.ingress_cidrs

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["${var.resource_name_label}-ingress-fw"]
}

resource "google_compute_firewall" "egress_firewall" {
  name          = "${var.resource_name_label}-egress-firewall"
  network       = var.vpc_id
  direction     = "EGRESS"
  source_ranges = var.egress_cidrs

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["${var.resource_name_label}-egress-fw"]
}

resource "google_compute_instance" "public_instance" {
  count        = var.vm_count
  name         = "${var.resource_name_label}-public-vm${count.index}"
  machine_type = local.instance_size
  zone         = local.zone1

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.public_subnet_id

    # assign external ephemeral IP
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.vm_admin_username}:${local.public_key}"
  }

  labels = merge(
    {
      name  = "${var.resource_name_label}-public-vm${count.index}-${var.region}",
      owner = var.owner
    },
    var.tags
  )

  tags = ["${var.resource_name_label}-ingress-fw", "${var.resource_name_label}-egress-fw"]

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "google_compute_instance" "private_instance" {
  count        = var.deploy_private_vm ? var.vm_count : 0
  name         = "${var.resource_name_label}-private-vm${count.index}"
  machine_type = local.instance_size
  zone         = local.zone2

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.private_subnet_id
  }

  metadata = {
    ssh-keys = "${var.vm_admin_username}:${local.public_key}"
  }

  labels = merge(
    {
      name  = "${var.resource_name_label}-private-vm${count.index}-${var.region}",
      owner = var.owner
    },
    var.tags
  )

  tags = ["${var.resource_name_label}-ingress-fw", "${var.resource_name_label}-egress-fw"]

  lifecycle {
    ignore_changes = [tags]
  }
}
