# ============================================================
# STAGE — IP Sets & Rules
# Add new IP-based WAF rules here.
# Each rule must reference a key defined in ip_sets.
# ============================================================

ip_sets = {
  # "BLOCKED_IPS" = {
  #   description        = "Known bad actors"
  #   ip_address_version = "IPV4"
  #   addresses          = ["1.2.3.4/32", "10.0.0.0/8"]
  # }
}

ip_set_rules = [
  # {
  #   name       = "BLOCK_BAD_IPS"
  #   priority   = 10
  #   action     = "block"
  #   ip_set_key = "BLOCKED_IPS"
  #   visibility_config = {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "BLOCKED_IPS"
  #     sampled_requests_enabled   = true
  #   }
  # },
]
