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

