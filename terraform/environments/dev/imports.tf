# ============================================================
# DEV — Import Blocks (Terraform 1.6+)
# Run scripts/discover_waf.sh dev us-east-1 <profile> first,
# then fill in the UUIDs from the backup JSON files.
#
# Uncomment each block and replace placeholders with real IDs,
# then run: terraform plan  (must show 0 changes after import)
# ============================================================

# ── Web ACL ────────────────────────────────────────────────
# import {
#   to = module.waf.aws_wafv2_web_acl.this
#   id = "gainsight-waf-dev/<WEB_ACL_UUID>/REGIONAL"
# }

# ── Regex Pattern Sets ────────────────────────────────────
# import {
#   to = module.waf.aws_wafv2_regex_pattern_set.this["XSS_CUSTOM_LATEST"]
#   id = "XSS_CUSTOM_LATEST/<REGEX_SET_UUID>/REGIONAL"
# }

# ── IP Sets ────────────────────────────────────────────────
# import {
#   to = module.waf.aws_wafv2_ip_set.this["BlocklistedIPs"]
#   id = "BlocklistedIPs/<IP_SET_UUID>/REGIONAL"
# }

# ── Web ACL Associations ───────────────────────────────────
# import {
#   to = module.waf.aws_wafv2_web_acl_association.this["<ALB_ARN>"]
#   id = "<ALB_ARN>/<WEB_ACL_ARN>"
# }

# ── Logging Configuration ──────────────────────────────────
# import {
#   to = module.waf.aws_wafv2_web_acl_logging_configuration.this[0]
#   id = "<WEB_ACL_ARN>"
# }
