# ============================================================
# imports.tf — Terraform 1.6+ import block reference
#
# This file is intentionally empty of active import blocks.
# All import blocks live in each environment's own imports.tf:
#   terraform/environments/<env>/imports.tf
#
# Import ID format per resource type:
#   aws_wafv2_web_acl                       → <name>/<id>/REGIONAL
#   aws_wafv2_ip_set                        → <name>/<id>/REGIONAL
#   aws_wafv2_regex_pattern_set             → <name>/<id>/REGIONAL
#   aws_wafv2_web_acl_association           → <resource_arn>/<web_acl_arn>
#   aws_wafv2_web_acl_logging_configuration → <web_acl_arn>
#
# Find all IDs by running:
#   terraform/scripts/discover_waf.sh <env> <region> <aws-profile>
# ============================================================
