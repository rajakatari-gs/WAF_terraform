# ============================================================
# STAGE — WAF Web ACL
# All WAF resources are managed exclusively through Terraform.
# Do NOT make changes directly in the AWS Console.
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

  # ── Rules (defined in *.auto.tfvars files) ───────────────
  regex_pattern_sets      = var.regex_pattern_sets
  ip_sets                 = var.ip_sets
  regex_pattern_set_rules = var.regex_pattern_set_rules
  ip_set_rules            = var.ip_set_rules
  rules                   = var.rules

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
