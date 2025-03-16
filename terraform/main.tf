# Declare varaibles for existing resources in AWS
data "aws_key_pair" "ssh_key" {
  key_name = "vpc-connection-key"
}

# add AMI Data Source
data "aws_ami" "ubuntu" {
  most_recent = true # select the latest Ubuntu 20.04 LTS Amazon Machine Image (AMI) from AWS

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] # wildcard (*) ensures that any newer AMI versions matching this name pattern will be included
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"] # ensures the AMI has hardware-assisted virtualization (HVM)
  }

  owners = ["099720109477"] # belongs to Canonical, the official provider of Ubuntu AMIs
}
/***************************** VPC Configuration ***********************************/
# Create a VPC with a CIDR block
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devops-team-vpc"
  }
}

# Add a public subnet resource
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id #associate subnet with the VPC created earlier
  cidr_block              = "10.0.41.0/24"
  map_public_ip_on_launch = true # instances launched in this subnet will automatically receive public IP addresses
  availability_zone       = "us-west-2a"

  tags = {
    Name = "public-subnet-devops"
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.devops_vpc.id  
  cidr_block              = "10.0.64.0/24"         
  map_public_ip_on_launch = true                    
  availability_zone       = "us-west-2b"           

  tags = {
    Name = "public-subnet-devops-2"
  }
}


# Add an Internet Gateway (IGW) to provide Internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id

  tags = {
    Name = "Internet-Gateway"
  }
}

# Define a route table that directs outbound traffic to the IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0" #route defined sends all traffic (0.0.0.0/0) to the Internet Gateway
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate the Public Subnet with the Route Table. 
# This association ensures that instances in the public subnet follow the routing rules defined in the route table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
/****************** Use module block to instantiate 3 private subnets ***************************/
module "private_subnet_1" {
  source            = "./modules/private-subnet"
  vpc_id            = aws_vpc.devops_vpc.id # Use ID of vpc as the value for the vpc_id variable inside the private-subnet module. 
  cidr_block        = "10.0.42.0/24"
  availability_zone = "us-west-2b"
  subnet_name       = "private-subnet-1"
}

module "private_subnet_2" {
  source            = "./modules/private-subnet"
  vpc_id            = aws_vpc.devops_vpc.id 
  cidr_block        = "10.0.43.0/24"
  availability_zone = "us-west-2c" 
  subnet_name       = "private-subnet-2"
}

module "private_subnet_3" {
  source            = "./modules/private-subnet"
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = "10.0.44.0/24"
  availability_zone = "us-west-2d" 
  subnet_name       = "private-subnet-3"
}

# NAT Gateway requires an Elastic IP (EIP) to allow outbound internet access
resource "aws_eip" "nat_gw_ip" {
  domain = "vpc"

  tags = {
    Name = "NAT-Gateway-EIP"
  }
}

# Create a NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw_ip.id
  subnet_id     = aws_subnet.public_subnet.id  # the NAT Gateway will be placed in the public subnet to allow private subnet instances to access the internet

  tags = {
    Name = "NAT-Gateway"
  }
}

#Create a Route Table for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

# Associate the PrivateRouteTable with the Private Subnet 3.
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = module.private_subnet_3.subnet_id
  route_table_id = aws_route_table.private_rt.id
}

output "private_subnet_1_id" {
  value = module.private_subnet_1.subnet_id
}

output "private_subnet_2_id" {
  value = module.private_subnet_2.subnet_id
}

output "private_subnet_3_id" {
  value = module.private_subnet_3.subnet_id
}


# Security Group for ALB (public access for frontend services)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic from the internet"
  vpc_id      = aws_vpc.devops_vpc.id

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
  vpc_id      = aws_vpc.devops_vpc.id

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
  vpc_id      = aws_vpc.devops_vpc.id

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
  vpc_id      = aws_vpc.devops_vpc.id

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
  vpc_id      = aws_vpc.devops_vpc.id

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


#EC2 Instance for Frontend (Vote & Result services)
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  security_groups        = [aws_security_group.frontend_sg.id]
  key_name               = data.aws_key_pair.ssh_key.key_name 

  tags = {
    Name = "Frontend-Server"
  }
}

# EC2 Instance for Backend (Redis & Worker services)
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  security_groups        = [aws_security_group.worker_sg.id]
  key_name               = data.aws_key_pair.ssh_key.key_name

  tags = {
    Name = "Backend-Server"
  }
}

# EC2 Instance for Database (PostgreSQL)
resource "aws_instance" "database" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  security_groups        = [aws_security_group.postgres_sg.id]
  key_name               = data.aws_key_pair.ssh_key.key_name

  tags = {
    Name = "Database-Server"
  }
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  internal           = false # Make it accessible from the internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_subnet.id,   
    aws_subnet.public_subnet_2.id 
  ]
  
  enable_deletion_protection = false
  tags = {
    Name = "Frontend-ALB"
  }
}

# Add a listener for the ALB (for HTTP traffic on port 80)
resource "aws_lb_listener" "frontend_alb_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "ALB is working!"
    }
  }
}

# Add a target group for the frontend EC2 instances
resource "aws_lb_target_group" "frontend_target_group" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.devops_vpc.id

  health_check {
    protocol = "HTTP"
    path     = "/"
    interval = 30
    timeout  = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "Frontend-Target-Group"
  }
}

# Register frontend EC2 instances with the target group
resource "aws_lb_target_group_attachment" "frontend_attachment" {
  target_group_arn = aws_lb_target_group.frontend_target_group.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}





