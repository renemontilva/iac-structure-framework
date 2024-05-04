mock_provider "aws" {}

run "networking_vpc" {
    command = apply

    assert {
        condition = module.vpc.name == "main-vpc"
        error_message = "VPC name is not correct"
    }

    assert {
        condition = module.vpc.vpc_cidr_block == "10.0.0.0/16" 
        error_message = "VPC CIDR is not correct"

    }
}

run "networking_subnets" {
    command = apply

    assert {
        condition = module.vpc.public_subnets_cidr_blocks == tolist(["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"])
        error_message = "Public subnets CIDR is not correct"
    }

    assert {
        condition = module.vpc.private_subnets_cidr_blocks == tolist(["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"])
        error_message = "Private subnets CIDR is not correct"
    }
}

run "networking_availability_zones" {
    command = apply

    assert {
        condition = module.vpc.azs == tolist(["us-east-1a", "us-east-1b", "us-east-1c"])
        error_message = "Availability zones are not correct"
    }
}
