#####################################################################
#              Integration Layer Module: Networking                 #
#####################################################################
module "core_networking" {
  source = "../../../modules/core-module/modules/networking"
}

#####################################################################
#              Integration Layer Module: Routing                    #
#####################################################################
module "core_routing" {
  source = "../../../modules/core-module/modules/routing"

  zone_name = "test.com"
}
