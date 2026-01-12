terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    google = {
      source = "hashicorp/google"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Provider aliases for each supported region
# -----------------------------------------------------------------------------
provider "aws" {
  alias      = "us-west-2"
  region     = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aws" {
  alias      = "us-east-1"
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aws" {
  alias      = "eu-west-1"
  region     = "eu-west-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aws" {
  alias      = "ap-southeast-1"
  region     = "ap-southeast-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# -----------------------------------------------------------------------------
# GCP Provider
# -----------------------------------------------------------------------------
provider "google" {
  project     = var.gcp_project_name
  region      = var.gcp_region
  credentials = file(var.gcp_credential_file_location)
}
