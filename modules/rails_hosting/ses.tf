resource "aws_ses_domain_identity" "email" {
  domain = aws_route53_record.web.fqdn
}

resource "aws_route53_record" "email" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.email.id}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.email.verification_token]
}

resource "aws_ses_domain_identity_verification" "email" {
  domain = aws_ses_domain_identity.email.id

  depends_on = [aws_route53_record.email]
}

resource "aws_ses_identity_policy" "email" {
  identity = aws_ses_domain_identity.email.arn
  name     = "${local.prefix}-web"
  policy = templatefile("${path.module}/templates/ses-policy.json.tftpl", {
    domain_arn : aws_ses_domain_identity.email.arn,
    role_arn : aws_iam_role.web_task.arn
  })
}
