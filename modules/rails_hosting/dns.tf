data "aws_route53_zone" "domain" {
  name = var.url_domain
}

resource "aws_route53_record" "web" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${var.environment}.${var.url_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.web.dns_name]
}

data "dns_a_record_set" "web" {
  host = aws_route53_record.web.name
}

resource "aws_acm_certificate" "web" {
  domain_name       = aws_route53_record.web.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "web_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "web" {
  certificate_arn = aws_acm_certificate.web.arn
  validation_record_fqdns = [
    for record in aws_route53_record.web_validation : record.fqdn
  ]
}
