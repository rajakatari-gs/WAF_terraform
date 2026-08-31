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
  description = "Deployment environment: stage, us1-prod, us2-prod, eu-prod"
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
# Rules
# ──────────────────────────────────────────────
variable "rules" {
  description = "List of WAF rules to attach to the Web ACL. Rule statements that reference IP sets or regex pattern sets must pass the ARN obtained from a data source in the calling environment."
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
  description = "Common tags applied to all WAF resources"
  type        = map(string)
  default     = {}
}
