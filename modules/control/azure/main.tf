module "transit" {
  source          = "./modules/transit"
  aws_ssm_region  = "us-east-2"
  region          = "East US 2"
  subscription_id = "47ab116c-8c15-4453-b06a-3fecd09ebda9"

  transits = {
    "az-westus-transit-vnet" = {
      cidr                   = "10.1.0.0/23"
      instance_size          = "Standard_D16_v5"
      account                = "lab-test-azure"
      local_as_number        = 65001
      fw_amount              = 2
      firewall_image_version = "11.2.5"
      vwan_connections = [
        {
          vwan_name     = "vwan-infra"
          vwan_hub_name = "infra"
        }
      ]
      ssh_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDa2Kz319A3dBeV/bBj5825OGarV5E6zyl70fa3SB2zh2EEsInFY6wj2Dac6nA6vGJTIC5bZPuOhJPsCuniUI+5o4C0df9V8lEQg7PLOcqdeZ3JklfzgvFK/YhWMDQnyJcOxGidVc6ywfyv0h+rbe5V1yhNvudTbvRn84hy/e/RJALBvIT1YUfr98cY+xloH0d/5wWIVtNj37xbwNDA4Eg2qO+84rBHGsIYS6wT+qXNH0IDW2SPQxmnIvf6Sweh2VnlFfn+/lcHhI7XcdjMsYFAKZjdu3ylnWLtbJw4FAY5rL0Q/OAako7pz3OFgGR2al6o/cYVxXjqsfz3yL6Ez32j ricardotrentin@Mac.attlocal.net"]
    }
  }

  # spokes = {
  #   "az-westus-spoke-vnet" = {
  #     cidr          = "10.18.0.0/24"
  #     instance_size = "Standard_D4_v5"
  #     account       = "lab-test-azure"
  #     enable_bgp    = false
  #   }
  # }

  vwan_configs = {
    "vwan-prod" = {
      location            = "East US"
      resource_group_name = "rg-vwan-prod"
      existing            = false
    }
    "vwan-infra" = {
      location            = "East US"
      resource_group_name = "rg-vwan-infra"
      existing            = false
    }
  }

  vwan_hubs = {
    "infra" = {
      virtual_hub_cidr = "10.2.0.0/24"
      azure_asn        = 65516
    }
    "prod" = {
      virtual_hub_cidr = "10.3.0.0/24"
    }
  }

  vnets = {
    # "workload1-vnet" = {
    #   cidr            = "10.4.0.0/16"
    #   private_subnets = ["10.4.1.0/24", "10.4.2.0/24"]
    #   public_subnets  = ["10.4.3.0/24", "10.4.4.0/24"]
    #   vwan_name       = "vwan-infra"
    #   vwan_hub_name   = "infra"
    # }
    # "workload2-vnet" = {
    #   resource_group_name = "rg-vnet-workload2-vnet-eastus"
    #   vwan_name           = "vwan-prod"
    #   vwan_hub_name       = "prod"
    #   existing            = true
    # }
  }

}
