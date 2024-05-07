provider "aws" {
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::333333333333:role/NetworkingStackRole"
    }
}
