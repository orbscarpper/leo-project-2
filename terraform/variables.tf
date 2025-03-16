variable "base_region" {
  description = "AWS region"
  type    = string
  default = "us-west-2" 
}

variable "s3_bucket_name" {
  description = "Name of the Amazon S3 bucket for storing terraform state"
  type    = string
  default = "devops-s3-bucket-terraform-state-storage" 
}

variable "dynamodb_table_name" {
  description = "Name of the  DynamoDB table for terraform state locking"
  type    = string
  default = "devops-terraform-state-lock" 
}
