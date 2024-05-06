provider "aws" {
  alias = "root_account"
  region = var.region
  access_key = "1111111111111"
}

provider "aws" {
  alias = "dev_account"
  region = var.region
  access_key = "222222222222"
}

provider "aws" {
  alias = "stg_account"
  region = var.region
  access_key = "333333333333"
}

provider "aws" {
  alias = "prd_account"
  region = var.region
  access_key = "444444444444"
}
