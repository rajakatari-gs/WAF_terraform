# ============================================================
# EU-PROD — WAF Web ACL
# PRODUCTION — Do not apply without a zero-change plan review
# ============================================================

module "waf" {
  source = "../../modules/waf"

  name        = "gainsight-waf-eu-prod"
  description = "WAF Web ACL for EU Production environment"
  scope       = "REGIONAL"
  environment = "eu-prod"

  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "gainsight-waf-eu-prod"
    sampled_requests_enabled   = true
  }

  ip_sets            = {}
  regex_pattern_sets = {}
  rules              = []

  association_resource_arns = []
  logging_configuration     = null

  tags = {
    Environment = "eu-prod"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
