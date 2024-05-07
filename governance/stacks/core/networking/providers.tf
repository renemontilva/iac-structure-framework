provider "aws" {
    alias = "dev_account"
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::222222222222:role/GovernanceRole"
    }
}

provider "aws" {
    alias = "stg_account"
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::333333333333:role/GovernanceRole"
    }
}

provider "aws" {
    alias = "prd_account"
    region = var.region
    assume_role {
        role_arn = "arn:aws:iam::444444444444:role/GovernanceRole"
    }
}
