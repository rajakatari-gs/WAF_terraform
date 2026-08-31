# ============================================================
# STAGE — WAF Web ACL
#
# IP sets and regex pattern sets are managed via the AWS Console.
# Use data sources below to look them up by name + ID, then
# reference their ARNs directly in rule statements.
# ============================================================

# ── Console-managed Regex Pattern Sets ───────────────────────
# Name and ID come from: AWS Console → WAF → Regex pattern sets
# Replace the id placeholder with the actual UUID shown in the Console.
data "aws_wafv2_regex_pattern_set" "xss_custom_latest" {
  name  = "XSS_CUSTOM_LATEST"
  id    = "REPLACE_WITH_STAGE_XSS_CUSTOM_LATEST_ID"
  scope = "REGIONAL"
}

# ── Console-managed IP Sets ───────────────────────────────────
# Uncomment and fill when an IP-set-based rule is needed.
# data "aws_wafv2_ip_set" "example" {
#   name  = "EXAMPLE_IP_SET"
#   id    = "REPLACE_WITH_IP_SET_ID"
#   scope = "REGIONAL"
# }

module "waf" {
  source = "../../modules/waf"

  name        = "gainsight-waf-stage"
  description = "WAF Web ACL for Stage environment"
  scope       = "REGIONAL"
  environment = "stage"

  default_action = "allow"

  # ── Visibility Config ─────────────────────────────────────
  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "gainsight-waf-stage"
    sampled_requests_enabled   = true
  }

  # ── Rules ────────────────────────────────────────────────
  rules = [
    {
      name     = "XSS_CUSTOM_LATEST"
      priority = 24
      action   = { count = {} }

      statement = {
        or_statement = {
          statements = [
            {
              regex_pattern_set_reference_statement = {
                arn            = data.aws_wafv2_regex_pattern_set.xss_custom_latest.arn
                field_to_match = { all_query_arguments = {} }
                text_transformation = [
                  { priority = 0, type = "URL_DECODE_UNI" }
                ]
              }
            },
            {
              regex_pattern_set_reference_statement = {
                arn = data.aws_wafv2_regex_pattern_set.xss_custom_latest.arn
                field_to_match = {
                  json_body = {
                    match_pattern     = { all = {} }
                    match_scope       = "ALL"
                    oversize_handling = "CONTINUE"
                  }
                }
                text_transformation = [
                  { priority = 0, type = "URL_DECODE_UNI" }
                ]
              }
            },
            {
              regex_pattern_set_reference_statement = {
                arn            = data.aws_wafv2_regex_pattern_set.xss_custom_latest.arn
                field_to_match = { uri_path = {} }
                text_transformation = [
                  { priority = 0, type = "URL_DECODE_UNI" }
                ]
              }
            },
          ]
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "CUSTOM_XSS"
        sampled_requests_enabled   = true
      }
    },
  ]

  # ── ALB / API GW Associations ────────────────────────────
  association_resource_arns = [
    # "arn:aws:elasticloadbalancing:us-east-1:ACCOUNT_ID:loadbalancer/app/stage-alb/XXXX"
  ]

  # ── Logging ──────────────────────────────────────────────
  logging_configuration = null
  # logging_configuration = {
  #   log_destination_configs = ["arn:aws:logs:us-east-1:ACCOUNT_ID:log-group:aws-waf-logs-stage"]
  # }

  tags = {
    Environment = "stage"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
