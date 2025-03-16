resource "aws_subnet" "private_subnet" {
  vpc_id            = var.vpc_id # values assigned to the module's input variables from main.tf.
  cidr_block        = var.cidr_block
  map_public_ip_on_launch = false   # No public IP for private subnet
  availability_zone = var.availability_zone

  tags = {
    Name = var.subnet_name
  }
}