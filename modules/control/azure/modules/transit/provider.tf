terraform {
  required_version = ">= 1.3"

  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "~> 8.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  alias  = "ssm"
  region = var.aws_ssm_region
}

provider "aviatrix" {
  controller_ip           = data.aws_ssm_parameter.aviatrix_ip.value
  username                = data.aws_ssm_parameter.aviatrix_username.value
  password                = data.aws_ssm_parameter.aviatrix_password.value
  skip_version_validation = false
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}