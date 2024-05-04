############################################
#              Networking                  #
############################################

data "aws_availability_zones" "available" {}

data "aws_vpc" "main" {
    filter {
        name   = "tag:Name"
        values = ["main-vpc"]
    }
}

data "aws_subnets" "private_subnets" {
    filter {
        name   = "tag:Name"
        values = ["*private*"]
    }
}

data "aws_subnet" "private_subnet" {
    for_each = toset(data.aws_subnets.private_subnets.ids)
    id = each.value
}

data "aws_subnets" "public_subnets" {
    filter {
        name   = "tag:Name"
        values = ["*public*"]
    }
}

data "aws_subnet" "public_subnet" {
    for_each = toset(data.aws_subnets.public_subnets.ids)
    id = each.value
}
