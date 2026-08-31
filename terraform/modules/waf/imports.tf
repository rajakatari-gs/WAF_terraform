# ============================================================
# imports.tf  — Terraform 1.6+ import blocks
#
# HOW TO USE:
#   1. Discover the live resource IDs using the scripts in
#      terraform/scripts/discover_waf.sh
#   2. Uncomment and fill in the correct id values below.
#   3. Run `terraform plan` — it must show 0 changes before
#      running `terraform apply` for the first time.
#
# Import ID format per resource type:
#   aws_wafv2_web_acl          → <name>/<id>/<scope>
#   aws_wafv2_ip_set           → <name>/<id>/<scope>
#   aws_wafv2_regex_pattern_set → <name>/<id>/<scope>
#   aws_wafv2_rule_group       → <name>/<id>/<scope>
#   aws_wafv2_web_acl_association → <resource_arn>/<web_acl_arn>
#   aws_wafv2_web_acl_logging_configuration → <web_acl_arn>
# ============================================================

# ── Example: Web ACL ───────────────────────────────────────
# import {
#   to = aws_wafv2_web_acl.this
#   id = "<WEB_ACL_NAME>/<WEB_ACL_ID>/REGIONAL"
# }

# ── Example: IP Set ────────────────────────────────────────
# import {
#   to = aws_wafv2_ip_set.this["<IP_SET_NAME>"]
#   id = "<IP_SET_NAME>/<IP_SET_ID>/REGIONAL"
# }

# ── Example: Regex Pattern Set ────────────────────────────
# import {
#   to = aws_wafv2_regex_pattern_set.this["<PATTERN_SET_NAME>"]
#   id = "<PATTERN_SET_NAME>/<PATTERN_SET_ID>/REGIONAL"
# }

# ── Example: Web ACL Association ──────────────────────────
# import {
#   to = aws_wafv2_web_acl_association.this["<ALB_ARN>"]
#   id = "<ALB_ARN>/<WEB_ACL_ARN>"
# }

# ── Example: Logging Configuration ───────────────────────
# import {
#   to = aws_wafv2_web_acl_logging_configuration.this[0]
#   id = "<WEB_ACL_ARN>"
# }
