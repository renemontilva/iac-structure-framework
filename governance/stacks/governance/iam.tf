########################################################################################
#                          IAM Role for Governance:                                    #
# This role is used by the Governance stack to manage permissions to all other stacks  #
########################################################################################

#### IAM Role and Policy for Governance ####

module "governance" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.root_account
  }

  create_role = true
  role_name   = "GovernanceRole"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::111111111111:root"
  ] 

  custom_role_policy_arns = [
    module.governance_policy.arn,
  ]
}

module "governance_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.root_account
  }
  
  name    = "GovernancePolicy"
  path    = "/"
  description = "IAM policy for Governance"
  policy = templatefile("${path.module}/policies/root_role_policy.json", {
    account_ids = jsonencode([
      module.dev_account_role.iam_role_arn,
      module.stg_account_role.iam_role_arn,
      module.prd_account_role.iam_role_arn
    ]) 
  })
}
  
#### IAM Role and Policy for Dev Account ####

module "dev_account_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.dev_account
  }

  create_role = true
  role_name   = "GovernanceRole"
  role_requires_mfa = false

  trusted_role_arns = [
    module.governance.iam_role_arn
  ]

  custom_role_policy_arns = [
    module.dev_account_policy.arn,
  ]
}

module "dev_account_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.dev_account
  }
  
  name    = "GovernancePolicy"
  path    = "/"
  description = "IAM policy for Dev Account"
  policy = templatefile("${path.module}/policies/stack_role_policies.json", {})
}

#### IAM Role and Policy for Staging Account ####

module "stg_account_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.stg_account
  }

  create_role = true
  role_name   = "GovernanceRole"
  role_requires_mfa = false

  trusted_role_arns = [
    module.governance.iam_role_arn
  ]

  custom_role_policy_arns = [
    module.stg_account_policy.arn,
  ]
}

module "stg_account_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.stg_account
  }
  
  name    = "GovernancePolicy"
  path    = "/"
  description = "IAM policy for Staging Account"
  policy = templatefile("${path.module}/policies/stack_role_policies.json", {})
}

#### IAM Role and Policy for Production Account ####

module "prd_account_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.39.0"
  providers = {
    aws = aws.prd_account
  }

  create_role = true
  role_name   = "GovernanceRole"
  role_requires_mfa = false

  trusted_role_arns = [
    module.governance.iam_role_arn
  ]

  custom_role_policy_arns = [
    module.prd_account_policy.arn,
  ]
}

module "prd_account_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.0"
  providers = {
    aws = aws.prd_account
  }
  
  name    = "GovernancePolicy"
  path    = "/"
  description = "IAM policy for Production Account"
  policy = templatefile("${path.module}/policies/stack_role_policies.json", {})
}
