# Configure AWS as the cloud provider in the us-east-1 region
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.46.0"
    }
  }

# Store terraform state file in a remote backend(S3) and enable state locking using DynamoDB
  backend "s3" {
    bucket         = "devops-s3-bucket-terraform-state-storage"  
    key            = "terraform.tfstate"          
    region         = "us-west-2"                
    encrypt        = true                        
    dynamodb_table = "devops-terraform-state-lock"       # DynamoDB table for state locking
  }

}

provider "aws" {
  region = var.base_region 
}
