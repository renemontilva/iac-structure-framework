output "vpc_id" {
  value = data.aws_vpc.main.id
  description = "The ID of the VPC"
}

output "vpc_cidr_block" {
  value = data.aws_vpc.main.cidr_block
  description = "The CIDR block of the VPC"
}

output "public_subnets_ids" {
  value = data.aws_subnets.public_subnets.ids
  description = "The IDs of the public subnets"
  
}

output "public_subnets_cidr_blocks" {
  value = [ for cidr in data.aws_subnet.public_subnet: cidr.cidr_block]
  description = "The CIDR blocks of the public subnets"
}

output "private_subnets_ids" {
  value = data.aws_subnets.private_subnets.ids
  description = "The IDs of the private subnets"
}

output "private_subnets_cidr_blocks" {
  value = [ for cidr in data.aws_subnet.private_subnet: cidr.cidr_block]
  description = "The CIDR blocks of the private subnets"
}

output "azs" {
  value = data.aws_availability_zones.available.names
  description = "The availability zones"
}
