data "aws_route53_zone" "zones" {
    name = var.zone_name
}
