output "zone_name" {
  value = data.aws_route53_zone.zones.name
  description = "The name of the zone"
}
