variable "aws_region" {
  description = "AWS region for US1-PROD environment"
  type        = string
  default     = "us-east-1"
}

variable "regex_pattern_sets" {
  description = "Regex pattern sets to create and manage via Terraform"
  type = map(object({
    description = string
    patterns    = list(string)
  }))
  default = {}
}

variable "regex_pattern_set_rules" {
  description = "WAF rules that reference regex pattern sets"
  type        = list(any)
  default     = []
}

variable "ip_sets" {
  description = "IP sets to create and manage via Terraform"
  type = map(object({
    description        = string
    ip_address_version = string
    addresses          = list(string)
  }))
  default = {}
}

variable "ip_set_rules" {
  description = "WAF rules that reference IP sets"
  type        = list(any)
  default     = []
}

variable "rules" {
  description = "Freeform WAF rules — managed rule groups, rate-based, geo-match, etc."
  type        = list(any)
  default     = []
}
