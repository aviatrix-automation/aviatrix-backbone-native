module "transit" {
  aws_ssm_region = "us-west-2"
  source         = "./modules/transit"
  project_id     = "rtrentin-01"
  ncc_hubs = [
    { name = "ai-1", create = true, preset_topology = "MESH" },
    { name = "ai-2", create = true, preset_topology = "MESH" },
  ]
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
        ai-1 = "10.1.0.0/24"
      }
      cloud_router_asn            = 16550
      aviatrix_gw_asn             = 65511
      fw_amount                   = 0
      firewall_image              = "vmseries-flex-byol"
      firewall_image_version      = "10210h14"
      manual_bgp_advertised_cidrs = ["0.0.0.0/0"]
      source_ranges               = ["10.0.0.0/8"]
      ssh_keys                    = "rtrentin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDa2Kz319A3dBeV/bBj5825OGarV5E6zyl70fa3SB2zh2EEsInFY6wj2Dac6nA6vGJTIC5bZPuOhJPsCuniUI+5o4C0df9V8lEQg7PLOcqdeZ3JklfzgvFK/YhWMDQnyJcOxGidVc6ywfyv0h+rbe5V1yhNvudTbvRn84hy/e/RJALBvIT1YUfr98cY+xloH0d/5wWIVtNj37xbwNDA4Eg2qO+84rBHGsIYS6wT+qXNH0IDW2SPQxmnIvf6Sweh2VnlFfn+/lcHhI7XcdjMsYFAKZjdu3ylnWLtbJw4FAY5rL0Q/OAako7pz3OFgGR2al6o/cYVxXjqsfz3yL6Ez32j ricardotrentin@Mac.attlocal.net"
      files = {
        "bootstrap/init-cfg.txt"  = "config/init-cfg.txt"
        "bootstrap/bootstrap.xml" = "config/bootstrap.xml"
      }
    },
    {
      access_account_name = "lab-test-gcp"
      service_account     = "controller@rtrentin-01.iam.gserviceaccount.com"
      gw_name             = "gcp-europe-west1-transit"
      project_id          = "rtrentin-01"
      region              = "europe-west1"
      zone                = "europe-west1-b"
      ha_zone             = "europe-west1-c"
      name                = "europe-west1-transit"
      vpc_cidr            = "10.2.240.0/24"
      lan_cidr            = "10.2.241.0/24"
      mgmt_cidr           = "10.2.242.0/24"
      egress_cidr         = "10.2.243.0/24"
      gw_size             = "n4-highcpu-8"
      bgp_lan_subnets = {
        ai-2 = "10.2.0.0/24"
      }
      cloud_router_asn            = 16550
      aviatrix_gw_asn             = 65512
      fw_amount                   = 0
      firewall_image              = "vmseries-flex-byol"
      firewall_image_version      = "10210h14"
      manual_bgp_advertised_cidrs = ["0.0.0.0/0"]
      source_ranges               = ["10.0.0.0/8"]
      ssh_keys                    = "rtrentin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDa2Kz319A3dBeV/bBj5825OGarV5E6zyl70fa3SB2zh2EEsInFY6wj2Dac6nA6vGJTIC5bZPuOhJPsCuniUI+5o4C0df9V8lEQg7PLOcqdeZ3JklfzgvFK/YhWMDQnyJcOxGidVc6ywfyv0h+rbe5V1yhNvudTbvRn84hy/e/RJALBvIT1YUfr98cY+xloH0d/5wWIVtNj37xbwNDA4Eg2qO+84rBHGsIYS6wT+qXNH0IDW2SPQxmnIvf6Sweh2VnlFfn+/lcHhI7XcdjMsYFAKZjdu3ylnWLtbJw4FAY5rL0Q/OAako7pz3OFgGR2al6o/cYVxXjqsfz3yL6Ez32j ricardotrentin@Mac.attlocal.net"
      files = {
        "bootstrap/init-cfg.txt"  = "config/init-cfg.txt"
        "bootstrap/bootstrap.xml" = "config/bootstrap.xml"
      }
    }
  ]
}