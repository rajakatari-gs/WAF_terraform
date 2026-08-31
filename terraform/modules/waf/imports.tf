# ============================================================
# imports.tf  — Terraform 1.6+ import block examples
#
# IP sets and regex pattern sets are managed via the AWS Console
# and are NOT imported into Terraform state. Only the Web ACL,
# its associations, and its logging configuration are managed here.
#
# HOW TO USE:
#   Uncomment and fill the relevant blocks in each environment's
#   own imports.tf (terraform/environments/<env>/imports.tf).
#
# Import ID format per resource type:
#   aws_wafv2_web_acl                       → <name>/<id>/REGIONAL
#   aws_wafv2_web_acl_association           → <resource_arn>/<web_acl_arn>
#   aws_wafv2_web_acl_logging_configuration → <web_acl_arn>
# ============================================================

# ── Example: Web ACL ───────────────────────────────────────
# import {
#   to = aws_wafv2_web_acl.this
#   id = "<WEB_ACL_NAME>/<WEB_ACL_ID>/REGIONAL"
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
