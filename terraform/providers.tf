# Configure AWS as the cloud provider in the us-east-1 region
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.46.0"
    }
  }

}

provider "aws" {
  region = var.base_region 
}
