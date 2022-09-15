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

        excluded_rule {
          name = "SizeRestrictions_BODY"
        }
      }
    }
  }

  rule {
    # TODO: This rule is currently hard coded to the /data_sets path. Make that
    # configurable.
    name     = "${local.prefix}-web-file-upload"
    priority = 2

    action {
      dynamic "count" {
        for_each = { for k, v in [var.passive_waf] : k => v if v }
        content {}
      }

      dynamic "block" {
        for_each = { for k, v in [var.passive_waf] : k => v if !v }
        content {}
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-web-file-upload"
      sampled_requests_enabled   = true
    }

    statement {
      and_statement {
        statement {
          label_match_statement {
            key   = "awswaf:managed:aws:core-rule-set:SizeRestrictions_Body"
            scope = "LABEL"
          }
        }
        statement {
          not_statement {
            statement {
              byte_match_statement {
                positional_constraint = "EXACTLY"
                search_string         = "/data_sets"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = aws_lb.web.arn
  web_acl_arn  = aws_wafv2_web_acl.web.arn
}
