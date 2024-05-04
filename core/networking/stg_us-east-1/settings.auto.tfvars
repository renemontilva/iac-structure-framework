region = "us-east-1"
network = {
  name               = "stg-us-east-1-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets    = ["10.0.20.0/24", "10.0.22.0/24", "10.0.22.0/24"]
  public_subnets     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "stg"
  }
}
