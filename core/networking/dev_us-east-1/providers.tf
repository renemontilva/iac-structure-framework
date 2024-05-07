provider "aws" {
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::222222222222:role/NetworkingStackRole"
    }
}
