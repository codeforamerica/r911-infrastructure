data "aws_route53_zone" "domain" {
  name = var.url_domain
}

resource "aws_route53_record" "warehouse" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "warehouse.${var.url_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.warehouse.dns_name]
}

resource "aws_acm_certificate" "warehouse" {
  domain_name       = aws_route53_record.warehouse.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "warehouse_validation" {
  for_each = {
    for dvo in aws_acm_certificate.warehouse.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "warehouse" {
  certificate_arn = aws_acm_certificate.warehouse.arn
  validation_record_fqdns = [
    for record in aws_route53_record.warehouse_validation : record.fqdn
  ]
}
