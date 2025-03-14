# S3 Bucket for Terraform state storage
/*
resource "aws_s3_bucket" "terraform_state" {
  bucket = "devops-s3-bucket-terraform-state-storage-new"

  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning for state file protection
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB Table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "devops-terraform-state-lock-new"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
*/