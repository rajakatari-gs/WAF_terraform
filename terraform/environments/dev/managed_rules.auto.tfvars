# ============================================================
# DEV — Managed Rule Groups & Freeform Rules
# Add AWS managed rule groups, rate-based rules, geo-match,
# and any other rule type here.
# Full statement block required for each entry.
# ============================================================

rules = [
  # AWS Managed — Common Rule Set
  # {
  #   name     = "AWSManagedRulesCommonRuleSet"
  #   priority = 1
  #   action   = { count = {} }
  #   statement = {
  #     managed_rule_group_statement = {
  #       name        = "AWSManagedRulesCommonRuleSet"
  #       vendor_name = "AWS"
  #     }
  #   }
  #   visibility_config = {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "AWSCommonRules"
  #     sampled_requests_enabled   = true
  #   }
  # },

  # Rate-Based Rule — limit to 1000 req/5min per IP
  # {
  #   name     = "RateLimitPerIP"
  #   priority = 5
  #   action   = { block = {} }
  #   statement = {
  #     rate_based_statement = {
  #       limit              = 1000
  #       aggregate_key_type = "IP"
  #     }
  #   }
  #   visibility_config = {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "RateLimitPerIP"
  #     sampled_requests_enabled   = true
  #   }
  # },

  # Geo-Match — block requests from specific countries
  # {
  #   name     = "GeoBlockHighRisk"
  #   priority = 3
  #   action   = { block = {} }
  #   statement = {
  #     geo_match_statement = {
  #       country_codes = ["KP", "IR"]
  #     }
  #   }
  #   visibility_config = {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "GeoBlock"
  #     sampled_requests_enabled   = true
  #   }
  # },
]
