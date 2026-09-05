# ============================================================
# EU-PROD — WAF Web ACL
# PRODUCTION — Do not apply without a zero-change plan review.
# All WAF resources are managed exclusively through Terraform.
# Do NOT make changes directly in the AWS Console.
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

  # ── Rules (defined in *.auto.tfvars files) ───────────────
  regex_pattern_sets      = var.regex_pattern_sets
  ip_sets                 = var.ip_sets
  regex_pattern_set_rules = var.regex_pattern_set_rules
  ip_set_rules            = var.ip_set_rules
  rules                   = var.rules

  # ── ALB / API GW Associations ────────────────────────────
  association_resource_arns = []

  # ── Logging ──────────────────────────────────────────────
  logging_configuration = null

  tags = {
    Environment = "eu-prod"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
