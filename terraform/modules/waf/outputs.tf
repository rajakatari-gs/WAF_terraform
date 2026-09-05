output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_capacity" {
  description = "WCU capacity consumed by this Web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

output "ip_set_arns" {
  description = "Map of IP set name → ARN for all Terraform-managed IP sets"
  value       = { for k, v in aws_wafv2_ip_set.this : k => v.arn }
}

output "regex_pattern_set_arns" {
  description = "Map of regex pattern set name → ARN for all Terraform-managed regex pattern sets"
  value       = { for k, v in aws_wafv2_regex_pattern_set.this : k => v.arn }
}
