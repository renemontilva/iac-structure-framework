mock_provider "aws" {}

run "routing_zone_names" {
  command = apply

  assert {
    condition     = module.dns.route53_zone_name["test.com"] == "test.com"
    error_message = "Route53 zone name: test.com is not correct"
  }

  assert {
    condition     = module.dns.route53_zone_name["test.internal"] == "test.internal"
    error_message = "Route53 zone name: test.internal is not correct"
  }
}

