# Output the Security Group ID for the ALB
output "alb_security_group_id" {
  description = "Security Group ID for the Application Load Balancer (ALB)"
  value       = aws_security_group.alb_sg.id
}

# Output the Security Group ID for the Frontend (Vote and Result services)
output "frontend_security_group_id" {
  description = "Security Group ID for the Frontend services (Vote and Result)"
  value       = aws_security_group.frontend_sg.id
}

# Output the Security Group ID for the Worker service
output "worker_security_group_id" {
  description = "Security Group ID for the Worker service"
  value       = aws_security_group.worker_sg.id
}

# Output the Security Group ID for Redis
output "redis_security_group_id" {
  description = "Security Group ID for Redis"
  value       = aws_security_group.redis_sg.id
}

# Output the Security Group ID for Postgres
output "postgres_security_group_id" {
  description = "Security Group ID for Postgres"
  value       = aws_security_group.postgres_sg.id
}

output "s3_bucket_name" {
    description = "Name of the S3 bucket used for storing terraform state"
    value = var.s3_bucket_name
}

output "dynamodb_table_name" {
    description = "Name of the DynamoDB tabel used for terraform state locking"
    value = var.dynamodb_table_name
}