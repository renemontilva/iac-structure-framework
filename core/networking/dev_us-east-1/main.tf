#####################################################################
#             Implementation Core Layer: Networking                 #
#####################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.network.name
  cidr = var.network.cidr

  azs             = var.network.azs
  private_subnets = var.network.private_subnets
  public_subnets  = var.network.public_subnets

  enable_nat_gateway = var.network.enable_nat_gateway
  enable_vpn_gateway = var.network.enable_vpn_gateway

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
