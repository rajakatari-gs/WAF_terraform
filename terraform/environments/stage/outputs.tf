output "web_acl_arn" {
  description = "Stage WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}

output "web_acl_id" {
  description = "Stage WAF Web ACL ID"
  value       = module.waf.web_acl_id
}
