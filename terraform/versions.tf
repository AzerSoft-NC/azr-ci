terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure remote state (DO Spaces example):
  # backend "s3" {
  #   endpoints = { s3 = "https://<region>.digitaloceanspaces.com" }
  #   bucket    = "azersoft-tfstate"
  #   key       = "infra/terraform.tfstate"
  #   region    = "us-east-1"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}

provider "digitalocean" {
  token = var.do_token
}
