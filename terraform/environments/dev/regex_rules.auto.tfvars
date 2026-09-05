# ============================================================
# DEV — Regex Pattern Sets & Rules
# Add new regex-based WAF rules here.
# Each rule must reference a key defined in regex_pattern_sets.
# ============================================================

regex_pattern_sets = {
  "XSS_CUSTOM_LATEST" = {
    description = "Custom XSS detection patterns"
    patterns = [
      "(?i)(<script\\b[^>]?.*(alert|prompt|confirm|eval)\\b)",
      "(?i)\\b(?:(?:on\\w+|xmlns)\\s*=\\s*[\"']?|javascript\\s*:\\s*[\"']?).?(?:alert|confirm|prompt|eval|write)(?:\\(|[`'`]?)\\b",
    ]
  }

  # "SQLI_CUSTOM" = {
  #   description = "Custom SQLi detection patterns"
  #   patterns = [
  #     "(?i)(union.*select|select.*from|drop.*table|insert.*into)"
  #   ]
  # }
}

regex_pattern_set_rules = [
  {
    name                        = "XSS_CUSTOM_LATEST"
    priority                    = 24
    action                      = "count"
    regex_pattern_set_key       = "XSS_CUSTOM_LATEST"
    fields_to_match             = ["ALL_QUERY_ARGUMENTS", "JSON_BODY", "URI_PATH"]
    json_body_match_scope       = "ALL"
    json_body_oversize_handling = "CONTINUE"
    text_transformations = [
      { priority = 0, type = "URL_DECODE_UNI" }
    ]
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "CUSTOM_XSS"
      sampled_requests_enabled   = true
    }
  },

  # {
  #   name                  = "SQLI_CUSTOM"
  #   priority              = 25
  #   action                = "count"
  #   regex_pattern_set_key = "SQLI_CUSTOM"
  #   fields_to_match       = ["ALL_QUERY_ARGUMENTS", "BODY"]
  #   text_transformations  = [{ priority = 0, type = "URL_DECODE_UNI" }]
  #   visibility_config = {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "CUSTOM_SQLI"
  #     sampled_requests_enabled   = true
  #   }
  # },
]
