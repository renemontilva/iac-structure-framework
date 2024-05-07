#####################################################################
#                Networking Stack Permissions                       #
#####################################################################

############################################################
# IAM Role and Policy for Networking Stack  on Dev Account #
############################################################

module "dev_networking_stack_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.dev_account
  }

  create_role = true
  role_name   = "NetworkingStackRole"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::222222222222:role/GovernanceRole"
  ] 

  custom_role_policy_arns = [
    module.networking_policy.arn,
  ]
}

module "dev_networking_stack_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.dev_account
  }
  
  name    = "NetworkingStackPolicy"
  path    = "/"
  description = "IAM policy for Networking Stack"
  policy = templatefile("${path.module}/policies/networking_stack_policy.json", {
    account_ids = jsonencode([
      module.dev_account_role.iam_role_arn,
      module.stg_account_role.iam_role_arn,
      module.prd_account_role.iam_role_arn
    ]) 
  })
}

################################################################
# IAM Role and Policy for Networking Stack  on Staging Account #
################################################################

module "stg_networking_stack_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.stg_account
  }

  create_role = true
  role_name   = "NetworkingStackRole"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::333333333333:role/GovernanceRole"
  ] 

  custom_role_policy_arns = [
    module.networking_policy.arn,
  ]
}

module "stg_networking_stack_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.stg_account
  }
  
  name    = "NetworkingStackPolicy"
  path    = "/"
  description = "IAM policy for Networking Stack"
  policy = templatefile("${path.module}/policies/networking_stack_policy.json", {
    account_ids = jsonencode([
      module.dev_account_role.iam_role_arn,
      module.stg_account_role.iam_role_arn,
      module.prd_account_role.iam_role_arn
    ]) 
  })
}

###################################################################
# IAM Role and Policy for Networking Stack  on Production Account #
###################################################################

module "prd_networking_stack_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.prd_account
  }

  create_role = true
  role_name   = "NetworkingStackRole"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::444444444444:role/GovernanceRole"
  ] 

  custom_role_policy_arns = [
    module.networking_policy.arn,
  ]
}

module "prd_networking_stack_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.prd_account
  }
  
  name    = "NetworkingStackPolicy"
  path    = "/"
  description = "IAM policy for Networking Stack"
  policy = templatefile("${path.module}/policies/networking_stack_policy.json", {
    account_ids = jsonencode([
      module.dev_account_role.iam_role_arn,
      module.stg_account_role.iam_role_arn,
      module.prd_account_role.iam_role_arn
    ]) 
  })
}
