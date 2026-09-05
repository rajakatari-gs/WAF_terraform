variable "name" {
  description = "Name of the WAF Web ACL"
  type        = string
}

variable "description" {
  description = "Description of the WAF Web ACL"
  type        = string
  default     = ""
}

variable "scope" {
  description = "Scope of the WAF: REGIONAL or CLOUDFRONT"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "environment" {
  description = "Deployment environment: dev, stage, us1-prod, us2-prod, eu-prod"
  type        = string
}

variable "default_action" {
  description = "Default action for the Web ACL: allow or block"
  type        = string
  default     = "allow"
  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be 'allow' or 'block'."
  }
}

# ──────────────────────────────────────────────
# IP Sets
# ──────────────────────────────────────────────
variable "ip_sets" {
  description = "Map of IP sets to create and manage. Key = resource name in AWS."
  type = map(object({
    description        = optional(string, "")
    ip_address_version = string # IPV4 or IPV6
    addresses          = list(string)
    tags               = optional(map(string), {})
  }))
  default = {}
}

# ──────────────────────────────────────────────
# Regex Pattern Sets
# ──────────────────────────────────────────────
variable "regex_pattern_sets" {
  description = "Map of regex pattern sets to create and manage. Key = resource name in AWS."
  type = map(object({
    description = optional(string, "")
    patterns    = list(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}

# ──────────────────────────────────────────────
# IP Set Rules
# Use this for rules whose statement is an ip_set_reference_statement
# referencing an IP set defined in var.ip_sets above.
# The module resolves the ARN internally — no cycle risk.
# ──────────────────────────────────────────────
variable "ip_set_rules" {
  description = "Rules that reference IP sets managed by this module."
  type = list(object({
    name       = string
    priority   = number
    action     = string # allow | block | count | captcha | challenge
    ip_set_key = string # must match a key in var.ip_sets
    visibility_config = object({
      cloudwatch_metrics_enabled = bool
      metric_name                = string
      sampled_requests_enabled   = bool
    })
  }))
  default = []
}

# ──────────────────────────────────────────────
# Regex Pattern Set Rules
# Use this for rules whose statement references a regex pattern set
# defined in var.regex_pattern_sets above.
# The module resolves the ARN internally — no cycle risk.
#
# fields_to_match values:
#   "ALL_QUERY_ARGUMENTS" | "URI_PATH" | "QUERY_STRING" | "METHOD" | "JSON_BODY"
#   Providing more than one value creates an or_statement automatically.
# ──────────────────────────────────────────────
variable "regex_pattern_set_rules" {
  description = "Rules that reference regex pattern sets managed by this module."
  type = list(object({
    name                        = string
    priority                    = number
    action                      = string # allow | block | count | captcha | challenge
    regex_pattern_set_key       = string # must match a key in var.regex_pattern_sets
    fields_to_match             = list(string)
    json_body_match_scope       = optional(string, "ALL")
    json_body_oversize_handling = optional(string, "CONTINUE")
    text_transformations = list(object({
      priority = number
      type     = string
    }))
    visibility_config = object({
      cloudwatch_metrics_enabled = bool
      metric_name                = string
      sampled_requests_enabled   = bool
    })
  }))
  default = []
}

# ──────────────────────────────────────────────
# Freeform Rules
# Use this for managed rule groups, rate-based rules, geo-match rules,
# or any rule type not covered by ip_set_rules / regex_pattern_set_rules.
# ──────────────────────────────────────────────
variable "rules" {
  description = "Freeform WAF rules (managed rule groups, rate-based, geo-match, etc.). Kept as 'any' to support all AWS WAF statement types."
  type        = any
  default     = []
}

# ──────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────
variable "logging_configuration" {
  description = "Logging configuration for the Web ACL (optional)"
  type = object({
    log_destination_configs = list(string)
    redacted_fields         = optional(list(any), [])
    logging_filter          = optional(any, null)
  })
  default = null
}

# ──────────────────────────────────────────────
# Visibility Config
# ──────────────────────────────────────────────
variable "visibility_config" {
  description = "Visibility/metrics configuration for the Web ACL"
  type = object({
    cloudwatch_metrics_enabled = bool
    metric_name                = string
    sampled_requests_enabled   = bool
  })
}

# ──────────────────────────────────────────────
# Associations
# ──────────────────────────────────────────────
variable "association_resource_arns" {
  description = "List of ALB/API Gateway ARNs to associate with this Web ACL"
  type        = list(string)
  default     = []
}

# ──────────────────────────────────────────────
# Tags
# ──────────────────────────────────────────────
variable "tags" {
  description = "Common tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
