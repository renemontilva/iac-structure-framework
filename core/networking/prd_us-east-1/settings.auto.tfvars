region = "us-east-1"
network = {
  name               = "prd-us-east-1-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets    = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]
  public_subnets     = ["10.0.301.0/24", "10.0.302.0/24", "10.0.303.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "prd"
  }
}
