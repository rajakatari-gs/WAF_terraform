output "web_acl_arn" {
  description = "Dev WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}

output "web_acl_id" {
  description = "Dev WAF Web ACL ID"
  value       = module.waf.web_acl_id
}
