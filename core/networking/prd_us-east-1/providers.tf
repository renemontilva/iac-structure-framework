provider "aws" {
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::444444444444:role/NetworkingStackRole"
    }
}
