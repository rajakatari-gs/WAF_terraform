# ============================================================
# STAGE — WAF Web ACL
# ============================================================

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

  # ── IP Sets ───────────────────────────────────────────────
  # Populate after running: scripts/discover_waf.sh stage
  ip_sets = {
    # "AllowlistedIPs" = {
    #   ip_address_version = "IPV4"
    #   addresses          = ["10.0.0.0/8"]
    # }
  }

  # ── Regex Pattern Sets ───────────────────────────────────
  regex_pattern_sets = {}

  # ── Rules ────────────────────────────────────────────────
  # Populated after discovery. See docs/RULE_SCHEMA.md
  rules = []

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
