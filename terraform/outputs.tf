output "s3_bucket_name" {
    description = "Name of the S3 bucket used for storing terraform state"
    value = var.s3_bucket_name
}

output "dynamodb_table_name" {
    description = "Name of the DynamoDB tabel used for terraform state locking"
    value = var.dynamodb_table_name
}