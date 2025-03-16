variable "vpc_id" {
  description = "The ID of the VPC where the private subnet will be created"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "The availability zone for the private subnet"
  type        = string
}

variable "subnet_name" {
  description = "The name of the private subnet"
  type        = string
}
