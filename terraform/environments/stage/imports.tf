# ============================================================
# STAGE — Import Blocks
# Fill these in after running: scripts/discover_waf.sh stage
#
# IP sets and regex pattern sets are console-managed and are
# NOT imported into Terraform state — do not add import blocks
# for them here.
# ============================================================

# import {
#   to = module.waf.aws_wafv2_web_acl.this
#   id = "gainsight-waf-stage/<WEB_ACL_ID>/REGIONAL"
# }

# import {
#   to = module.waf.aws_wafv2_web_acl_association.this["<ALB_ARN>"]
#   id = "<ALB_ARN>/<WEB_ACL_ARN>"
# }

# import {
#   to = module.waf.aws_wafv2_web_acl_logging_configuration.this[0]
#   id = "<WEB_ACL_ARN>"
# }
