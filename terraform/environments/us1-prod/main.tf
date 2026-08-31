# ============================================================
# US1-PROD — WAF Web ACL
# PRODUCTION — Do not apply without a zero-change plan review
#
# IP sets and regex pattern sets are managed via the AWS Console.
# Use data sources below to look them up by name + ID, then
# reference their ARNs directly in rule statements.
# ============================================================

# ── Console-managed Regex Pattern Sets ───────────────────────
# Uncomment and fill after running: scripts/discover_waf.sh us1-prod
# data "aws_wafv2_regex_pattern_set" "xss_custom_latest" {
#   name  = "XSS_CUSTOM_LATEST"
#   id    = "REPLACE_WITH_US1_PROD_XSS_CUSTOM_LATEST_ID"
#   scope = "REGIONAL"
# }

# ── Console-managed IP Sets ───────────────────────────────────
# data "aws_wafv2_ip_set" "example" {
#   name  = "EXAMPLE_IP_SET"
#   id    = "REPLACE_WITH_IP_SET_ID"
#   scope = "REGIONAL"
# }

module "waf" {
  source = "../../modules/waf"

  name        = "gainsight-waf-us1-prod"
  description = "WAF Web ACL for US1 Production environment"
  scope       = "REGIONAL"
  environment = "us1-prod"

  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "gainsight-waf-us1-prod"
    sampled_requests_enabled   = true
  }

  # ── Rules ────────────────────────────────────────────────
  # Populate after running: scripts/discover_waf.sh us1-prod
  rules = []

  # ── ALB / API GW Associations ────────────────────────────
  association_resource_arns = []

  # ── Logging ──────────────────────────────────────────────
  logging_configuration = null

  tags = {
    Environment = "us1-prod"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
