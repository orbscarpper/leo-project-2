# Define the AWS provider and region
provider "aws" {
  region = "us-west-2"
}

# Data resource to get the existing VPC by its ID
data "aws_vpc" "main_vpc" {
  id = "vpc-026c0966fe3ce6ffc" 
}

# Security Group for ALB (public access for frontend services)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic from the internet"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Security Group for Frontend (Vote, Result) services
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow ALB traffic to frontend services"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Only ALB can access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# Security Group for Worker (Backend service)
resource "aws_security_group" "worker_sg" {
  name        = "worker-sg"
  description = "Allow communication with Redis and Postgres"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "worker-sg"
  }
}

# Security Group for Redis
resource "aws_security_group" "redis_sg" {
  name        = "redis-sg"
  description = "Allow communication from Worker on Redis port (6379)"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis-sg"
  }
}

# Security Group for Postgres
resource "aws_security_group" "postgres_sg" {
  name        = "postgres-sg"
  description = "Allow communication from Worker on Postgres port (5432)"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-sg"
  }
}
