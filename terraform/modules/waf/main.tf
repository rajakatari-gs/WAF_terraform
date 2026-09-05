# ============================================================
# WAF Module — main.tf
# Manages: IP Sets, Regex Pattern Sets, Web ACL, Associations,
#          and Logging Configuration.
#
# Rule types handled by this module:
#   1. ip_set_rules              — rules referencing managed IP sets
#   2. regex_pattern_set_rules   — rules referencing managed regex pattern sets
#   3. rules                     — freeform rules (managed rule groups, rate-based, etc.)
#
# The module resolves IP set and regex pattern set ARNs internally so that
# callers never need to reference module outputs inside the same module call
# (which would create a Terraform dependency cycle).
#
# PRODUCTION-SAFETY NOTE:
#   On first run this module is import-only.
#   Do NOT run `terraform apply` against production until
#   `terraform plan` shows zero unintended changes.
# ============================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ──────────────────────────────────────────────
# IP Sets
# ──────────────────────────────────────────────
resource "aws_wafv2_ip_set" "this" {
  for_each = var.ip_sets

  name               = each.key
  description        = each.value.description
  scope              = var.scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses

  tags = merge(var.tags, each.value.tags)
}

# ──────────────────────────────────────────────
# Regex Pattern Sets
# ──────────────────────────────────────────────
resource "aws_wafv2_regex_pattern_set" "this" {
  for_each = var.regex_pattern_sets

  name        = each.key
  description = each.value.description
  scope       = var.scope

  dynamic "regular_expression" {
    for_each = each.value.patterns
    content {
      regex_string = regular_expression.value
    }
  }

  tags = merge(var.tags, each.value.tags)
}

# ──────────────────────────────────────────────
# Internal rule construction
# ARNs are resolved here so callers don't need to
# reference module outputs inside the same call.
# ──────────────────────────────────────────────
locals {
  # Common field_to_match structures (empty-content blocks)
  _ftm = {
    "ALL_QUERY_ARGUMENTS" = { all_query_arguments = {} }
    "URI_PATH"            = { uri_path = {} }
    "QUERY_STRING"        = { query_string = {} }
    "METHOD"              = { method = {} }
  }

  # Rules that reference internally-managed regex pattern sets.
  # Supports any number of fields_to_match; >1 becomes an or_statement.
  _regex_pattern_set_rules = [
    for r in var.regex_pattern_set_rules : {
      name     = r.name
      priority = r.priority
      action   = { (r.action) = {} }
      statement = length(r.fields_to_match) == 1 ? {
        regex_pattern_set_reference_statement = {
          arn = aws_wafv2_regex_pattern_set.this[r.regex_pattern_set_key].arn
          field_to_match = r.fields_to_match[0] == "JSON_BODY" ? {
            json_body = {
              match_pattern     = { all = {} }
              match_scope       = r.json_body_match_scope
              oversize_handling = r.json_body_oversize_handling
            }
          } : local._ftm[r.fields_to_match[0]]
          text_transformation = r.text_transformations
        }
      } : {
        or_statement = {
          statements = [
            for f in r.fields_to_match : {
              regex_pattern_set_reference_statement = {
                arn = aws_wafv2_regex_pattern_set.this[r.regex_pattern_set_key].arn
                field_to_match = f == "JSON_BODY" ? {
                  json_body = {
                    match_pattern     = { all = {} }
                    match_scope       = r.json_body_match_scope
                    oversize_handling = r.json_body_oversize_handling
                  }
                } : local._ftm[f]
                text_transformation = r.text_transformations
              }
            }
          ]
        }
      }
      visibility_config = r.visibility_config
    }
  ]

  # Rules that reference internally-managed IP sets.
  _ip_set_rules = [
    for r in var.ip_set_rules : {
      name     = r.name
      priority = r.priority
      action   = { (r.action) = {} }
      statement = {
        ip_set_reference_statement = {
          arn = aws_wafv2_ip_set.this[r.ip_set_key].arn
        }
      }
      visibility_config = r.visibility_config
    }
  ]

  # Final ordered rule list: ip_set → regex → freeform (var.rules)
  all_rules = concat(local._ip_set_rules, local._regex_pattern_set_rules, var.rules)
}

# ──────────────────────────────────────────────
# Web ACL
# ──────────────────────────────────────────────
resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = local.all_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = try([rule.value.action], [])
        content {
          dynamic "allow" {
            for_each = try(action.value.allow != null ? [1] : [], [])
            content {}
          }
          dynamic "block" {
            for_each = try(action.value.block != null ? [1] : [], [])
            content {}
          }
          dynamic "count" {
            for_each = try(action.value.count != null ? [1] : [], [])
            content {}
          }
          dynamic "captcha" {
            for_each = try(action.value.captcha != null ? [1] : [], [])
            content {}
          }
          dynamic "challenge" {
            for_each = try(action.value.challenge != null ? [1] : [], [])
            content {}
          }
        }
      }

      dynamic "override_action" {
        for_each = try([rule.value.override_action], [])
        content {
          dynamic "none" {
            for_each = try(override_action.value.none != null ? [1] : [], [])
            content {}
          }
          dynamic "count" {
            for_each = try(override_action.value.count != null ? [1] : [], [])
            content {}
          }
        }
      }

      statement = rule.value.statement

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.visibility_config.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.visibility_config.cloudwatch_metrics_enabled
    metric_name                = var.visibility_config.metric_name
    sampled_requests_enabled   = var.visibility_config.sampled_requests_enabled
  }

  tags = var.tags
}

# ──────────────────────────────────────────────
# Web ACL Associations
# ──────────────────────────────────────────────
resource "aws_wafv2_web_acl_association" "this" {
  for_each = toset(var.association_resource_arns)

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# ──────────────────────────────────────────────
# Logging Configuration
# ──────────────────────────────────────────────
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.logging_configuration != null ? 1 : 0

  log_destination_configs = var.logging_configuration.log_destination_configs
  resource_arn            = aws_wafv2_web_acl.this.arn

  dynamic "redacted_fields" {
    for_each = var.logging_configuration.redacted_fields
    content {
      dynamic "single_header" {
        for_each = try([redacted_fields.value.single_header], [])
        content {
          name = single_header.value.name
        }
      }
    }
  }

  dynamic "logging_filter" {
    for_each = var.logging_configuration.logging_filter != null ? [var.logging_configuration.logging_filter] : []
    content {
      default_behavior = logging_filter.value.default_behavior
      dynamic "filter" {
        for_each = logging_filter.value.filters
        content {
          behavior    = filter.value.behavior
          requirement = filter.value.requirement
          dynamic "condition" {
            for_each = filter.value.conditions
            content {
              dynamic "action_condition" {
                for_each = try([condition.value.action_condition], [])
                content {
                  action = action_condition.value.action
                }
              }
              dynamic "label_name_condition" {
                for_each = try([condition.value.label_name_condition], [])
                content {
                  label_name = label_name_condition.value.label_name
                }
              }
            }
          }
        }
      }
    }
  }
}
