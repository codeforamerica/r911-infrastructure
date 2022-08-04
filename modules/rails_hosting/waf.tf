resource "aws_wafv2_web_acl" "web" {
  name        = "${local.prefix}-web"
  description = "Web Application Firewall for ${var.project} web - ${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-web"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "${local.prefix}-web-aws-ip-reputation-list"
    priority = 0

    override_action {

      dynamic "count" {
        for_each = { for k, v in [var.passive_waf] : k => v if v }
        content {}
      }

      dynamic "none" {
        for_each = { for k, v in [var.passive_waf] : k => v if !v }
        content {}
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-web-aws-ip-reputation-list"
      sampled_requests_enabled   = true
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
  }

  rule {
    name     = "${local.prefix}-web-aws-common-rules"
    priority = 1

    override_action {
      dynamic "count" {
        for_each = { for k, v in [var.passive_waf] : k => v if v }
        content {}
      }

      dynamic "none" {
        for_each = { for k, v in [var.passive_waf] : k => v if !v }
        content {}
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-web-aws-common-rules"
      sampled_requests_enabled   = true
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
  }
}

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = aws_lb.web.arn
  web_acl_arn  = aws_wafv2_web_acl.web.arn
}
