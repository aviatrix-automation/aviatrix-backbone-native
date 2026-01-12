module "transit" {
  aws_ssm_region = "us-west-2"
  source         = "./modules/transit"
  region         = "us-east-1"
  tags           = {
    Environment = "dev"
    Owner       = "your-team"
  }
  transits = {
    aws-tr-prod-1 = {
      account                = "lab-test-aws"
      cidr                   = "10.0.0.0/23"
      instance_size          = "c5n.9xlarge"
      local_as_number        = 65011
      fw_amount              = 2
      firewall_image         = "6njl1pau431dv1qxipg63mvah"
      firewall_image_version = "12.1.3-h2"
      tgw_name               = "prod"
      inside_cidr_blocks = {
        "prod" = {
          connect_peer_1    = "169.254.101.0/29"
          ha_connect_peer_1 = "169.254.201.0/29"
          connect_peer_2    = "169.254.102.0/29"
          ha_connect_peer_2 = "169.254.202.0/29"
          connect_peer_3    = "169.254.103.0/29"
          ha_connect_peer_3 = "169.254.203.0/29"
          connect_peer_4    = "169.254.104.0/29"
          ha_connect_peer_4 = "169.254.204.0/29"
          connect_peer_5    = "169.254.105.0/29"
          ha_connect_peer_5 = "169.254.205.0/29"
          connect_peer_6    = "169.254.106.0/29"
          ha_connect_peer_6 = "169.254.206.0/29"
          connect_peer_7    = "169.254.107.0/29"
          ha_connect_peer_7 = "169.254.207.0/29"
          connect_peer_8    = "169.254.108.0/29"
          ha_connect_peer_8 = "169.254.208.0/29"
        }
      }
      manual_bgp_advertised_cidrs = ["0.0.0.0/0"]
      mgmt_source_ranges   = ["10.0.0.0/8"]
      egress_source_ranges = ["10.0.0.0/8"]
      lan_source_ranges    = ["10.0.0.0/8"]
    }
  }
  tgws = {
    prod = {
      amazon_side_asn             = 64512
      transit_gateway_cidr_blocks = ["172.16.0.0/24"]
      create_tgw                  = true
      account_ids                 = []
    }
  }

  #spokes = {
  #  app-spoke-1 = {
  #    account                = "lab-test-aws"
  #    attached               = true
  #    cidr                   = "10.10.0.0/16"
  #    insane_mode            = true
  #    enable_max_performance = true
  #    transit_key            = "aws-transit-prod-1"
  #  }
  #}
}

