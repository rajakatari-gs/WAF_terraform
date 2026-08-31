# ============================================================
# US2-PROD — WAF Web ACL
# PRODUCTION — Do not apply without a zero-change plan review
# ============================================================

module "waf" {
  source = "../../modules/waf"

  name        = "gainsight-waf-us2-prod"
  description = "WAF Web ACL for US2 Production environment"
  scope       = "REGIONAL"
  environment = "us2-prod"

  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "gainsight-waf-us2-prod"
    sampled_requests_enabled   = true
  }

  ip_sets            = {}
  regex_pattern_sets = {}
  rules              = []

  association_resource_arns = []
  logging_configuration     = null

  tags = {
    Environment = "us2-prod"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
