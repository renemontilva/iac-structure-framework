#####################################################################
#             Implementation Core Layer: Routing                    #
#####################################################################
module "dns" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.11.1"

  zones = {
    "test.com" = {
      comment = "Test domain"
      tags = {
        Terraform   = "true"
        Environment = "dev"
      }

    }
    "test.internal" = {
      comment = "Private domain"
      tags = {
        Terraform   = "true"
        Environment = "dev"
      }
      vpc = [
        {
          vpc_id = module.core_networking.vpc_id
        }
      ]
    }
  }
  tags = var.tags
}
