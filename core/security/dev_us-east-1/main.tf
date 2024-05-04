#####################################################################
#              Integration Layer Module: Networking                 #
#####################################################################
module "core_networking" {
  source = "../../../modules/core-module/modules/networking"
}

module "core_routing" {
  source = "../../../modules/core-module/modules/routing"

  zone_name = "test.com"
}

#####################################################################
#             Implementation Core Layer: Security                   #
#####################################################################

############################################
#            Security Groups               #
############################################ 

module "security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "allow_all"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = module.core_networking.vpc_id

  ingress_cidr_blocks = [""]
  
}

############################################
#    IAM: Identity and Access Management   #
############################################

#module "iam" {
#  source = "terraform-aws-modules/iam/aws"
#  version = "5.39.0"
#}

############################################
#    KMS: Key Management Service           #
############################################

#module "kms" {
#  source = "terraform-aws-modules/kms/aws"
#  version = "2.2.1"
#}

############################################
#        SM: Secrets Manager               #
############################################

#module "secrets_manager" {
#  source = "terraform-aws-modules/secrets-manager/aws"
#  version = "1.1.2"
#}


############################################
#    SSM: Systems Manager Parameter Store  #
############################################

#module "ssm-parameter" {
#  source  = "terraform-aws-modules/ssm-parameter/aws"
#  version = "1.1.1"
#}

############################################
#      ACM:  Certificate Manager           #
############################################

#module "acm" {
#  source  = "terraform-aws-modules/acm/aws"
#  version = "5.0.1"
#}
