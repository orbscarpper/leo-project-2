output "subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private_subnet.id
}
