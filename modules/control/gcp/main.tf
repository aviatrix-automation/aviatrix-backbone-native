module "transit" {
  aws_ssm_region = "us-west-2"
  source         = "./modules/transit"
  project_id     = "rtrentin-01"
  ncc_hubs = [
    # {
    #   name                 = "ai-1"
    #   create               = false
    #   existing_vpc_name    = "bgp-lan-ai-1-vpc" # REQUIRED when create = false
    #   existing_vpc_project = "rtrentin-01"      # Optional: defaults to project_id
    #   preset_topology      = "MESH"
    # },
    {
      name            = "ai-2"
      create          = true
      preset_topology = "MESH"
    },
  ]
  aviatrix_spokes = {
    "gcp-us-spoke-test" = {
      account          = "lab-test-gcp"
      region           = "us-east1"
      attached         = true
      cidr             = "10.10.0.0/24"
      transit_gw_name  = "gcp-us-transit"
      insane_mode      = false
      single_ip_snat   = true
      allocate_new_eip = true
    }
  }
  transits = [
    {
      access_account_name = "lab-test-gcp"
      service_account     = "controller@rtrentin-01.iam.gserviceaccount.com"
      gw_name             = "gcp-us-transit"
      project_id          = "rtrentin-01"
      region              = "us-east1"
      zone                = "us-east1-b"
      ha_zone             = "us-east1-c"
      name                = "gcp-us-transit"
      vpc_cidr            = "10.1.240.0/24"
      lan_cidr            = "10.1.241.0/24"
      mgmt_cidr           = "10.1.242.0/24"
      egress_cidr         = "10.1.243.0/24"
      gw_size             = "n4-highcpu-8"
      bgp_lan_subnets = {
        # ai-1 = {
        #   cidr                 = "10.1.0.0/24"
        #   existing_subnet_name = "gcp-us-transit-bgp-lan-ai-1-subnet" # For existing VPC
        # }
        ai-2 = {
          cidr = "10.2.0.0/24"
        }
      }

      cloud_router_asn            = 16550
      aviatrix_gw_asn             = 65511
      fw_amount                   = 2
      firewall_image              = "vmseries-flex-byol"
      firewall_image_version      = "10210h14"
      manual_bgp_advertised_cidrs = ["0.0.0.0/0"]
      bgp_lan_connection_cidrs = {
        #"ai-1" = ["0.0.0.0/0"]
      }

      # Gateway-level: Enable connection-based learned CIDR approval mode
      learned_cidr_approval       = "false" # Must be false for connection mode
      learned_cidrs_approval_mode = "connection"
      # Per-connection learned CIDR approval (key = NCC hub name)
      bgp_lan_connection_learned_cidr_approval = {
        #"ai-1" = true
      }
      bgp_lan_connection_approved_cidrs = {
        #"ai-1" = ["0.0.0.0/0"] # Empty = block all learned routes
      }
      external_lb_rules = [
        { name = "app-http", frontend_port = 80, backend_port = 80, destination_ip = "10.10.0.10", health_check = true },
      ]
      source_ranges = ["0.0.0.0/0"]
      ssh_keys      = "rtrentin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDa2Kz319A3dBeV/bBj5825OGarV5E6zyl70fa3SB2zh2EEsInFY6wj2Dac6nA6vGJTIC5bZPuOhJPsCuniUI+5o4C0df9V8lEQg7PLOcqdeZ3JklfzgvFK/YhWMDQnyJcOxGidVc6ywfyv0h+rbe5V1yhNvudTbvRn84hy/e/RJALBvIT1YUfr98cY+xloH0d/5wWIVtNj37xbwNDA4Eg2qO+84rBHGsIYS6wT+qXNH0IDW2SPQxmnIvf6Sweh2VnlFfn+/lcHhI7XcdjMsYFAKZjdu3ylnWLtbJw4FAY5rL0Q/OAako7pz3OFgGR2al6o/cYVxXjqsfz3yL6Ez32j ricardotrentin@Mac.attlocal.net"
      files = {
        "bootstrap/init-cfg.txt"  = "config/init-cfg.txt"
        "bootstrap/bootstrap.xml" = "config/bootstrap.xml"
      }
    }
  ]
}

# --- Test VM running nginx in the spoke VPC ---
data "google_compute_network" "spoke_vpc" {
  name    = "gcp-us-spoke-test"
  project = "rtrentin-01"

  depends_on = [module.transit]
}

data "google_compute_subnetwork" "spoke_subnet" {
  name    = "gcp-us-spoke-test"
  region  = "us-east1"
  project = "rtrentin-01"

  depends_on = [module.transit]
}

resource "google_compute_firewall" "spoke_allow_internal" {
  name    = "spoke-test-allow-internal"
  project = "rtrentin-01"
  network = data.google_compute_network.spoke_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

resource "google_compute_firewall" "spoke_allow_iap_ssh" {
  name    = "spoke-test-allow-iap-ssh"
  project = "rtrentin-01"
  network = data.google_compute_network.spoke_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_instance" "nginx_test" {
  name         = "nginx-test-vm"
  project      = "rtrentin-01"
  zone         = "us-east1-b"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.spoke_subnet.self_link
    network_ip = "10.10.0.10"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Aviatrix Spoke Test VM - $(hostname)</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOT

  metadata = {
    ssh-keys = "rtrentin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDa2Kz319A3dBeV/bBj5825OGarV5E6zyl70fa3SB2zh2EEsInFY6wj2Dac6nA6vGJTIC5bZPuOhJPsCuniUI+5o4C0df9V8lEQg7PLOcqdeZ3JklfzgvFK/YhWMDQnyJcOxGidVc6ywfyv0h+rbe5V1yhNvudTbvRn84hy/e/RJALBvIT1YUfr98cY+xloH0d/5wWIVtNj37xbwNDA4Eg2qO+84rBHGsIYS6wT+qXNH0IDW2SPQxmnIvf6Sweh2VnlFfn+/lcHhI7XcdjMsYFAKZjdu3ylnWLtbJw4FAY5rL0Q/OAako7pz3OFgGR2al6o/cYVxXjqsfz3yL6Ez32j ricardotrentin@Mac.attlocal.net"
  }

  tags = ["nginx-test"]
}