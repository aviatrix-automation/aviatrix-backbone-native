module "transit" {
  aws_ssm_region = "us-west-2"
  source         = "./modules/transit"
  region         = "us-east-1"
  tags = {
    Environment = "dev"
    Owner       = "your-team"
  }
  transits = {
    aws-tr-prod-1 = {
      account                = "lab-test-aws"
      cidr                   = "10.0.0.0/23"
      instance_size          = "c5n.9xlarge"
      local_as_number        = 65011
      fw_amount              = 0
      firewall_image         = "6njl1pau431dv1qxipg63mvah"
      firewall_image_version = "12.1.3-h2"
      tgw_name               = "prod,non-prod"
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
        },
        "non-prod" = {
          connect_peer_1    = "169.254.111.0/29"
          ha_connect_peer_1 = "169.254.211.0/29"
          connect_peer_2    = "169.254.112.0/29"
          ha_connect_peer_2 = "169.254.212.0/29"
          connect_peer_3    = "169.254.113.0/29"
          ha_connect_peer_3 = "169.254.213.0/29"
          connect_peer_4    = "169.254.114.0/29"
          ha_connect_peer_4 = "169.254.214.0/29"
          connect_peer_5    = "169.254.115.0/29"
          ha_connect_peer_5 = "169.254.215.0/29"
          connect_peer_6    = "169.254.116.0/29"
          ha_connect_peer_6 = "169.254.216.0/29"
          connect_peer_7    = "169.254.117.0/29"
          ha_connect_peer_7 = "169.254.217.0/29"
          connect_peer_8    = "169.254.118.0/29"
          ha_connect_peer_8 = "169.254.218.0/29"
        }
      }
      manual_bgp_advertised_cidrs = ["0.0.0.0/0"]
      tgw_connection_cidrs = {
        "prod"     = ["10.1.0.0/16", "10.2.0.0/16"]
        "non-prod" = ["10.3.0.0/16"]
      }
      # Gateway-level: Enable connection-based learned CIDR approval mode
      learned_cidr_approval       = "false" # Must be false for connection mode
      learned_cidrs_approval_mode = "connection"
      # Per-connection learned CIDR approval configuration
      tgw_connection_learned_cidr_approval = {
        "prod"     = true
        "non-prod" = true
      }
      tgw_connection_approved_cidrs = {
        "prod"     = []
        "non-prod" = []
      }
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
    },
    non-prod = {
      amazon_side_asn             = 64522
      transit_gateway_cidr_blocks = ["172.32.0.0/24"]
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

